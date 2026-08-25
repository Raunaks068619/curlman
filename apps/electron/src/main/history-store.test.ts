// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { createEmptyRequest, type ResponseSnapshot } from '../shared/models';
import { HistoryStore } from './history-store';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) fs.rmSync(directory, { recursive: true, force: true });
});

describe('HistoryStore', () => {
  it('persists finalized requests and pin state across reopen', async () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'curlman-history-'));
    temporaryDirectories.push(directory);
    const databasePath = path.join(directory, 'history.sqlite');
    const wasmPath = path.resolve('node_modules/sql.js/dist/sql-wasm.wasm');
    const store = await HistoryStore.open(databasePath, wasmPath);
    const request = createEmptyRequest();
    request.method = 'POST';
    request.urlString = 'https://example.com/items';
    const id = store.begin(request);
    store.finalize(id, successfulResponse());
    store.togglePin(id);

    const reopened = await HistoryStore.open(databasePath, wasmPath);
    const entries = reopened.list();

    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({ id, isPinned: true, request: { method: 'POST' }, response: { statusCode: 201 } });
  });
});

function successfulResponse(): ResponseSnapshot {
  const body = Buffer.from('{"ok":true}');
  return {
    id: crypto.randomUUID(),
    statusCode: 201,
    reasonPhrase: 'Created',
    headers: { 'content-type': 'application/json' },
    bodyText: body.toString('utf8'),
    bodyBase64: body.toString('base64'),
    mimeType: 'application/json',
    durationMs: 42,
    receivedByteCount: body.byteLength,
    wasCancelled: false,
    receivedAt: new Date().toISOString(),
  };
}
