import { z } from 'zod';

export const HTTPMethods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'] as const;
export const BodyKinds = ['JSON', 'Raw', 'None'] as const;
export const AuthenticationKinds = ['None', 'Bearer', 'Basic'] as const;

export const KeyValueItemSchema = z.object({
  id: z.string(),
  isEnabled: z.boolean(),
  name: z.string(),
  value: z.string(),
});

export const AuthenticationSchema = z.object({
  kind: z.enum(AuthenticationKinds),
  username: z.string(),
  secret: z.string(),
  credentialID: z.string().optional(),
});

export const RequestDraftSchema = z.object({
  id: z.string(),
  name: z.string(),
  method: z.enum(HTTPMethods),
  urlString: z.string(),
  queryItems: z.array(KeyValueItemSchema),
  headers: z.array(KeyValueItemSchema),
  bodyKind: z.enum(BodyKinds),
  body: z.string(),
  authentication: AuthenticationSchema,
});

export const ResponseSnapshotSchema = z.object({
  id: z.string(),
  statusCode: z.number().int().optional(),
  reasonPhrase: z.string(),
  headers: z.record(z.string(), z.string()),
  bodyText: z.string(),
  bodyBase64: z.string(),
  mimeType: z.string().optional(),
  durationMs: z.number(),
  receivedByteCount: z.number().int(),
  errorDescription: z.string().optional(),
  wasCancelled: z.boolean(),
  receivedAt: z.string(),
});

export const HistoryEntrySchema = z.object({
  id: z.string(),
  startedAt: z.string(),
  displayName: z.string(),
  request: RequestDraftSchema,
  response: ResponseSnapshotSchema,
  isPinned: z.boolean(),
});

export type HTTPMethod = (typeof HTTPMethods)[number];
export type BodyKind = (typeof BodyKinds)[number];
export type AuthenticationKind = (typeof AuthenticationKinds)[number];
export type KeyValueItem = z.infer<typeof KeyValueItemSchema>;
export type Authentication = z.infer<typeof AuthenticationSchema>;
export type RequestDraft = z.infer<typeof RequestDraftSchema>;
export type ResponseSnapshot = z.infer<typeof ResponseSnapshotSchema>;
export type HistoryEntry = z.infer<typeof HistoryEntrySchema>;

export interface CurlImportResult {
  request: RequestDraft;
  warnings: string[];
}

export function createKeyValueItem(name = '', value = ''): KeyValueItem {
  return { id: crypto.randomUUID(), isEnabled: true, name, value };
}

export function createEmptyRequest(): RequestDraft {
  return {
    id: crypto.randomUUID(),
    name: '',
    method: 'GET',
    urlString: '',
    queryItems: [createKeyValueItem()],
    headers: [createKeyValueItem()],
    bodyKind: 'JSON',
    body: '',
    authentication: { kind: 'None', username: '', secret: '' },
  };
}
