import fs from 'node:fs';
import path from 'node:path';
import { safeStorage } from 'electron';
import type { RequestDraft } from '../shared/models';

export class CredentialVault {
  private readonly memory = new Map<string, string>();
  private encrypted: Record<string, string> = {};

  constructor(private readonly filePath: string) {
    this.load();
  }

  capture(request: RequestDraft): RequestDraft {
    if (request.authentication.kind === 'None' || !request.authentication.secret) return request;
    const credentialID = request.authentication.credentialID ?? crypto.randomUUID();
    const secret = request.authentication.secret;
    this.memory.set(credentialID, secret);
    if (safeStorage.isEncryptionAvailable()) {
      this.encrypted[credentialID] = safeStorage.encryptString(secret).toString('base64');
      this.persist();
    }
    return { ...request, authentication: { ...request.authentication, credentialID } };
  }

  restore(request: RequestDraft): RequestDraft {
    const credentialID = request.authentication.credentialID;
    if (!credentialID) return request;
    const memorySecret = this.memory.get(credentialID);
    if (memorySecret) return withSecret(request, memorySecret);
    const encoded = this.encrypted[credentialID];
    if (!encoded || !safeStorage.isEncryptionAvailable()) return request;
    try {
      const secret = safeStorage.decryptString(Buffer.from(encoded, 'base64'));
      this.memory.set(credentialID, secret);
      return withSecret(request, secret);
    } catch {
      return request;
    }
  }

  private load(): void {
    if (!fs.existsSync(this.filePath)) return;
    try {
      this.encrypted = JSON.parse(fs.readFileSync(this.filePath, 'utf8')) as Record<string, string>;
    } catch {
      this.encrypted = {};
    }
  }

  private persist(): void {
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    const temporaryPath = `${this.filePath}.tmp`;
    fs.writeFileSync(temporaryPath, JSON.stringify(this.encrypted), { mode: 0o600 });
    fs.renameSync(temporaryPath, this.filePath);
  }
}

export function sanitizeRequest(request: RequestDraft): RequestDraft {
  return {
    ...request,
    authentication: { ...request.authentication, secret: '' },
    headers: request.headers.map((header) =>
      header.name.toLowerCase() === 'authorization' ? { ...header, value: '<stored securely>' } : header,
    ),
  };
}

function withSecret(request: RequestDraft, secret: string): RequestDraft {
  return { ...request, authentication: { ...request.authentication, secret } };
}
