import fs from 'node:fs';
import path from 'node:path';
import initSqlJs, { type Database, type SqlJsStatic } from 'sql.js';
import { HistoryEntrySchema, type HistoryEntry, type RequestDraft, type ResponseSnapshot } from '../shared/models';

const responseBodyLimit = 2 * 1024 * 1024;

export class HistoryStore {
  private constructor(
    private readonly database: Database,
    private readonly databasePath: string,
  ) {}

  static async open(databasePath: string, wasmPath: string): Promise<HistoryStore> {
    const wasmBinary = Uint8Array.from(fs.readFileSync(wasmPath)).buffer;
    const SQL: SqlJsStatic = await initSqlJs({ wasmBinary });
    const bytes = fs.existsSync(databasePath) ? fs.readFileSync(databasePath) : undefined;
    const store = new HistoryStore(new SQL.Database(bytes), databasePath);
    store.createSchema();
    store.reconcilePending();
    return store;
  }

  begin(request: RequestDraft): string {
    const id = crypto.randomUUID();
    this.database.run(
      `INSERT INTO history (id, started_at, display_name, method, url, request_json, response_json, status_code, duration_ms, response_size, is_pinned)
       VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, 0, 0, 0)`,
      [id, new Date().toISOString(), request.name, request.method, request.urlString, JSON.stringify(request)],
    );
    this.persist();
    return id;
  }

  finalize(id: string, response: ResponseSnapshot): void {
    const storedResponse = truncateResponse(response);
    this.database.run(
      `UPDATE history SET response_json = ?, status_code = ?, duration_ms = ?, response_size = ? WHERE id = ?`,
      [JSON.stringify(storedResponse), response.statusCode ?? null, response.durationMs, response.receivedByteCount, id],
    );
    this.persist();
  }

  list(): HistoryEntry[] {
    const statement = this.database.prepare(
      `SELECT id, started_at, display_name, request_json, response_json, is_pinned
       FROM history WHERE response_json IS NOT NULL ORDER BY is_pinned DESC, started_at DESC`,
    );
    const entries: HistoryEntry[] = [];
    while (statement.step()) entries.push(entryFromRow(statement.getAsObject()));
    statement.free();
    return entries;
  }

  get(id: string): HistoryEntry {
    const statement = this.database.prepare(
      `SELECT id, started_at, display_name, request_json, response_json, is_pinned FROM history WHERE id = ?`,
    );
    statement.bind([id]);
    if (!statement.step()) {
      statement.free();
      throw new Error('History entry not found.');
    }
    const entry = entryFromRow(statement.getAsObject());
    statement.free();
    return entry;
  }

  togglePin(id: string): void {
    this.database.run(`UPDATE history SET is_pinned = CASE is_pinned WHEN 0 THEN 1 ELSE 0 END WHERE id = ?`, [id]);
    this.persist();
  }

  delete(id: string): void {
    this.database.run('DELETE FROM history WHERE id = ?', [id]);
    this.persist();
  }

  clear(): void {
    this.database.run('DELETE FROM history');
    this.persist();
  }

  private createSchema(): void {
    this.database.run(`
      CREATE TABLE IF NOT EXISTS history (
        id TEXT PRIMARY KEY,
        started_at TEXT NOT NULL,
        display_name TEXT NOT NULL,
        method TEXT NOT NULL,
        url TEXT NOT NULL,
        request_json TEXT NOT NULL,
        response_json TEXT,
        status_code INTEGER,
        duration_ms REAL NOT NULL,
        response_size INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0
      )
    `);
    this.persist();
  }

  private reconcilePending(): void {
    const statement = this.database.prepare('SELECT id FROM history WHERE response_json IS NULL');
    const pendingIDs: string[] = [];
    while (statement.step()) pendingIDs.push(String(statement.getAsObject().id));
    statement.free();
    for (const id of pendingIDs) this.finalize(id, interruptedResponse());
  }

  private persist(): void {
    fs.mkdirSync(path.dirname(this.databasePath), { recursive: true });
    const temporaryPath = `${this.databasePath}.tmp`;
    fs.writeFileSync(temporaryPath, this.database.export(), { mode: 0o600 });
    fs.renameSync(temporaryPath, this.databasePath);
  }
}

function entryFromRow(row: Record<string, unknown>): HistoryEntry {
  return HistoryEntrySchema.parse({
    id: row.id,
    startedAt: row.started_at,
    displayName: row.display_name,
    request: JSON.parse(String(row.request_json)),
    response: JSON.parse(String(row.response_json)),
    isPinned: row.is_pinned === 1,
  });
}

function truncateResponse(response: ResponseSnapshot): ResponseSnapshot {
  const bytes = Buffer.from(response.bodyBase64, 'base64');
  if (bytes.byteLength <= responseBodyLimit) return response;
  const stored = bytes.subarray(0, responseBodyLimit);
  return { ...response, bodyBase64: stored.toString('base64'), bodyText: stored.toString('utf8') };
}

function interruptedResponse(): ResponseSnapshot {
  return {
    id: crypto.randomUUID(),
    reasonPhrase: '',
    headers: {},
    bodyText: '',
    bodyBase64: '',
    durationMs: 0,
    receivedByteCount: 0,
    errorDescription: 'Request interrupted when Curlman closed.',
    wasCancelled: true,
    receivedAt: new Date().toISOString(),
  };
}
