import {
  createEmptyRequest,
  createKeyValueItem,
  HTTPMethods,
  type CurlImportResult,
  type HTTPMethod,
  type RequestDraft,
} from './models';

export class CurlImportError extends Error {}

export function parseCurl(command: string): CurlImportResult {
  const tokens = tokenizeCurl(command);
  const executable = tokens[0];
  if (!executable || (executable !== 'curl' && !executable.endsWith('/curl'))) {
    throw new CurlImportError('The pasted text is not a curl command.');
  }

  const request = createEmptyRequest();
  request.queryItems = [];
  request.headers = [];
  request.bodyKind = 'None';
  const warnings: string[] = [];
  let explicitMethod: HTTPMethod | undefined;
  let inferredPost = false;
  let forceGet = false;
  let index = 1;

  const nextValue = (option: string): string => {
    const value = tokens[index + 1];
    if (value === undefined) throw new CurlImportError(`The curl option ${option} is missing its value.`);
    index += 1;
    return value;
  };

  while (index < tokens.length) {
    const token = tokens[index] ?? '';
    if (token === '-X' || token === '--request') {
      explicitMethod = parseMethod(nextValue(token), warnings);
    } else if (token.startsWith('--request=')) {
      explicitMethod = parseMethod(token.slice('--request='.length), warnings);
    } else if (token === '-H' || token === '--header') {
      applyHeader(nextValue(token), request, warnings);
    } else if (token.startsWith('--header=')) {
      applyHeader(token.slice('--header='.length), request, warnings);
    } else if (['-d', '--data', '--data-raw', '--data-binary'].includes(token)) {
      applyBody(nextValue(token), request);
      inferredPost = true;
    } else if (['--data=', '--data-raw=', '--data-binary='].some((prefix) => token.startsWith(prefix))) {
      const prefix = ['--data=', '--data-raw=', '--data-binary='].find((value) => token.startsWith(value)) ?? '';
      applyBody(token.slice(prefix.length), request);
      inferredPost = true;
    } else if (token === '--data-urlencode') {
      applyURLEncodedBody(nextValue(token), request, warnings);
      inferredPost = true;
    } else if (token.startsWith('--data-urlencode=')) {
      applyURLEncodedBody(token.slice('--data-urlencode='.length), request, warnings);
      inferredPost = true;
    } else if (token === '-u' || token === '--user') {
      applyBasicAuth(nextValue(token), request);
    } else if (token.startsWith('--user=')) {
      applyBasicAuth(token.slice('--user='.length), request);
    } else if (token === '--url') {
      request.urlString = nextValue(token);
    } else if (token.startsWith('--url=')) {
      request.urlString = token.slice('--url='.length);
    } else if (token === '-G' || token === '--get') {
      forceGet = true;
    } else if (['-L', '--location', '--location-trusted'].includes(token)) {
      // Redirect following is the default request behavior.
    } else if (takesIgnoredValue(token)) {
      nextValue(token);
      warnings.push(`Ignored unsupported curl option: ${token}`);
    } else if (token.startsWith('-')) {
      warnings.push(`Ignored unsupported curl option: ${token}`);
    } else if (!request.urlString) {
      request.urlString = token;
    } else {
      warnings.push(`Ignored extra argument: ${token}`);
    }
    index += 1;
  }

  if (!request.urlString) throw new CurlImportError('The curl command does not contain a URL.');
  splitQueryItems(request);
  formatJSONBody(request);
  if (forceGet) {
    request.method = 'GET';
    appendBodyAsQueryItems(request);
  } else if (explicitMethod) {
    request.method = explicitMethod;
  } else if (inferredPost) {
    request.method = 'POST';
  }
  if (request.headers.length === 0) request.headers = [createKeyValueItem()];
  if (request.queryItems.length === 0) request.queryItems = [createKeyValueItem()];
  return { request, warnings };
}

export function tokenizeCurl(command: string): string[] {
  const normalized = command.replace(/\\\r?\n/g, ' ');
  const tokens: string[] = [];
  let current = '';
  let quote: "'" | '"' | undefined;
  let escaping = false;
  let tokenStarted = false;

  for (const character of normalized) {
    if (escaping) {
      current += character;
      escaping = false;
      tokenStarted = true;
    } else if (character === '\\' && quote !== "'") {
      escaping = true;
      tokenStarted = true;
    } else if (quote) {
      if (character === quote) quote = undefined;
      else current += character;
      tokenStarted = true;
    } else if (character === "'" || character === '"') {
      quote = character;
      tokenStarted = true;
    } else if (/\s/.test(character)) {
      if (tokenStarted) {
        tokens.push(current);
        current = '';
        tokenStarted = false;
      }
    } else {
      current += character;
      tokenStarted = true;
    }
  }
  if (escaping) current += '\\';
  if (quote) throw new CurlImportError('The curl command contains an unterminated quote.');
  if (tokenStarted) tokens.push(current);
  return tokens;
}

export function exportCurl(draft: RequestDraft): string {
  const url = buildURL(draft);
  const headers = enabledHeaders(draft);
  if (draft.authentication.kind === 'Bearer' && draft.authentication.secret) {
    headers.Authorization = `Bearer ${draft.authentication.secret}`;
  } else if (draft.authentication.kind === 'Basic') {
    headers.Authorization = `Basic ${encodeBase64(`${draft.authentication.username}:${draft.authentication.secret}`)}`;
  }
  if (draft.bodyKind === 'JSON' && draft.body && !hasHeader(headers, 'content-type')) {
    headers['Content-Type'] = 'application/json';
  }

  const argumentsList = [`curl --request ${draft.method}`, `--url ${shellQuote(url)}`];
  for (const [name, value] of Object.entries(headers).sort(([a], [b]) => a.localeCompare(b))) {
    argumentsList.push(`--header ${shellQuote(`${name}: ${value}`)}`);
  }
  if (draft.bodyKind !== 'None' && draft.body) argumentsList.push(`--data-raw ${shellQuote(draft.body)}`);
  return argumentsList.join(' \\\n  ');
}

export function buildURL(draft: RequestDraft): string {
  let url: URL;
  try {
    url = new URL(draft.urlString);
  } catch {
    throw new Error('The URL is invalid.');
  }
  for (const item of draft.queryItems) {
    if (item.isEnabled && item.name) url.searchParams.append(item.name, item.value);
  }
  return url.toString();
}

export function enabledHeaders(draft: RequestDraft): Record<string, string> {
  return Object.fromEntries(draft.headers.filter((item) => item.isEnabled && item.name).map((item) => [item.name, item.value]));
}

function parseMethod(raw: string, warnings: string[]): HTTPMethod | undefined {
  const method = raw.toUpperCase();
  if (HTTPMethods.includes(method as HTTPMethod)) return method as HTTPMethod;
  warnings.push(`Unsupported HTTP method: ${method}`);
  return undefined;
}

function applyHeader(raw: string, request: RequestDraft, warnings: string[]): void {
  const separator = raw.indexOf(':');
  if (separator < 0) {
    warnings.push(`Ignored malformed header: ${raw}`);
    return;
  }
  const name = raw.slice(0, separator).trim();
  const value = raw.slice(separator + 1).trim();
  if (name.toLowerCase() === 'authorization' && value.toLowerCase().startsWith('bearer ')) {
    request.authentication = {
      kind: 'Bearer',
      username: '',
      secret: value.slice(7),
      credentialID: request.authentication.credentialID ?? crypto.randomUUID(),
    };
    return;
  }
  if (name.toLowerCase() === 'authorization' && value.toLowerCase().startsWith('basic ')) {
    warnings.push('Imported an encoded Basic Authorization header as a normal header. Use Auth to edit it safely.');
  }
  request.headers.push(createKeyValueItem(name, value));
}

function applyBody(value: string, request: RequestDraft): void {
  request.body = request.body ? `${request.body}&${value}` : value;
  const contentType = request.headers.find((item) => item.name.toLowerCase() === 'content-type')?.value.toLowerCase();
  const firstCharacter = value.trim()[0];
  request.bodyKind = contentType?.includes('application/json') || firstCharacter === '{' || firstCharacter === '[' ? 'JSON' : 'Raw';
}

function applyURLEncodedBody(value: string, request: RequestDraft, warnings: string[]): void {
  const separator = value.indexOf('=');
  const fileMarker = value.indexOf('@');
  if (fileMarker >= 0 && (separator < 0 || fileMarker < separator)) {
    warnings.push('Ignored file-based --data-urlencode input for safety. Paste the value directly instead.');
    return;
  }
  const encoded = separator < 0
    ? encodeURIComponent(value)
    : `${encodeURIComponent(value.slice(0, separator))}=${encodeURIComponent(value.slice(separator + 1))}`;
  applyBody(encoded, request);
}

function applyBasicAuth(value: string, request: RequestDraft): void {
  const separator = value.indexOf(':');
  request.authentication = {
    kind: 'Basic',
    username: separator < 0 ? value : value.slice(0, separator),
    secret: separator < 0 ? '' : value.slice(separator + 1),
    credentialID: request.authentication.credentialID ?? crypto.randomUUID(),
  };
}

function splitQueryItems(request: RequestDraft): void {
  try {
    const url = new URL(request.urlString);
    for (const [name, value] of url.searchParams) request.queryItems.push(createKeyValueItem(name, value));
    url.search = '';
    request.urlString = url.toString();
  } catch {
    // Validation reports malformed URLs after import.
  }
}

function appendBodyAsQueryItems(request: RequestDraft): void {
  if (!request.body) return;
  const params = new URLSearchParams(request.body);
  for (const [name, value] of params) request.queryItems.push(createKeyValueItem(name, value));
  request.body = '';
  request.bodyKind = 'None';
}

function formatJSONBody(request: RequestDraft): void {
  if (request.bodyKind !== 'JSON' || !request.body.trim()) return;
  try {
    request.body = JSON.stringify(JSON.parse(request.body), null, 2);
  } catch {
    // Keep invalid JSON editable and report it through validation.
  }
}

function takesIgnoredValue(option: string): boolean {
  return ['--proxy', '-x', '--connect-timeout', '--max-time', '--cacert', '--cert', '--key', '--cookie', '-b', '--cookie-jar', '-c', '--output', '-o'].includes(option);
}

function hasHeader(headers: Record<string, string>, name: string): boolean {
  return Object.keys(headers).some((header) => header.toLowerCase() === name.toLowerCase());
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function encodeBase64(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}
