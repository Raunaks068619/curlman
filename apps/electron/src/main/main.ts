import path from 'node:path';
import { app, BrowserWindow, clipboard, globalShortcut, ipcMain, nativeImage, session, Tray, type Rectangle } from 'electron';
import { buildURL, enabledHeaders, exportCurl, parseCurl } from '../shared/curl';
import { RequestDraftSchema, type RequestDraft, type ResponseSnapshot } from '../shared/models';
import { CredentialVault, sanitizeRequest } from './credential-vault';
import { HistoryStore } from './history-store';
import { PreferencesStore } from './preferences-store';
import { isTrustedFrame } from './security';

declare const MAIN_WINDOW_VITE_DEV_SERVER_URL: string | undefined;
declare const MAIN_WINDOW_VITE_NAME: string;

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let isQuitting = false;
let activeRequest: AbortController | null = null;
let registeredAccelerator: string | null = null;
let expandedBounds: Rectangle | null = null;
let isCompact = false;

function createWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: 760,
    height: 500,
    minWidth: 560,
    minHeight: 360,
    show: false,
    skipTaskbar: true,
    title: 'Curlman',
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'hidden',
    titleBarOverlay: process.platform === 'darwin' ? false : { color: '#00000000', symbolColor: '#777777' },
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.webContents.on('will-navigate', (event, destination) => {
    if (destination !== window.webContents.getURL()) event.preventDefault();
  });
  window.on('close', (event) => {
    if (!isQuitting) {
      event.preventDefault();
      window.hide();
    }
  });
  window.once('ready-to-show', () => window.show());

  if (MAIN_WINDOW_VITE_DEV_SERVER_URL) {
    void window.loadURL(MAIN_WINDOW_VITE_DEV_SERVER_URL);
  } else {
    void window.loadFile(path.join(__dirname, `../renderer/${MAIN_WINDOW_VITE_NAME}/index.html`));
  }
  return window;
}

function toggleWindow(): void {
  if (!mainWindow) return;
  if (mainWindow.isVisible()) {
    mainWindow.hide();
  } else {
    mainWindow.show();
    mainWindow.focus();
  }
}

function createTray(): Tray {
  const iconPath = path.join(app.getAppPath(), 'Brand/Curlman-Icon.png');
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 18, height: 18 });
  const nextTray = new Tray(icon);
  nextTray.setToolTip('Curlman');
  nextTray.on('click', toggleWindow);
  return nextTray;
}

function registerIPC(history: HistoryStore, credentials: CredentialVault, preferences: PreferencesStore): void {
  ipcMain.handle('desktop:get-platform', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    return process.platform;
  });
  ipcMain.handle('desktop:get-version', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    return app.getVersion();
  });
  ipcMain.handle('desktop:hide-window', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    BrowserWindow.fromWebContents(event.sender)?.hide();
  });
  ipcMain.handle('request:import-curl', (event, command: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    if (typeof command !== 'string') throw new Error('The cURL command must be text.');
    return parseCurl(command);
  });
  ipcMain.handle('request:copy-curl', (event, input: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    const command = exportCurl(RequestDraftSchema.parse(input));
    clipboard.writeText(command);
    return command;
  });
  ipcMain.handle('request:execute', async (event, input: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    const request = credentials.capture(RequestDraftSchema.parse(input));
    const historyID = history.begin(sanitizeRequest(request));
    activeRequest?.abort();
    const controller = new AbortController();
    activeRequest = controller;
    try {
      const response = await executeRequest(request, controller.signal);
      history.finalize(historyID, response);
      return response;
    } finally {
      if (activeRequest === controller) activeRequest = null;
    }
  });
  ipcMain.handle('request:cancel', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    activeRequest?.abort();
  });
  ipcMain.handle('history:list', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    return history.list();
  });
  ipcMain.handle('history:restore', (event, id: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    if (typeof id !== 'string') throw new Error('Invalid history identifier.');
    const entry = history.get(id);
    return { ...entry, request: credentials.restore(entry.request) };
  });
  ipcMain.handle('history:toggle-pin', (event, id: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    if (typeof id !== 'string') throw new Error('Invalid history identifier.');
    history.togglePin(id);
  });
  ipcMain.handle('history:delete', (event, id: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    if (typeof id !== 'string') throw new Error('Invalid history identifier.');
    history.delete(id);
  });
  ipcMain.handle('history:clear', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    history.clear();
  });
  ipcMain.handle('settings:get-shortcut', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    return {
      accelerator: preferences.shortcut.shortcut,
      display: preferences.shortcut.shortcutDisplay,
      registered: registeredAccelerator === preferences.shortcut.shortcut,
    };
  });
  ipcMain.handle('settings:set-shortcut', (event, accelerator: unknown, display: unknown) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    if (typeof accelerator !== 'string' || typeof display !== 'string') throw new Error('Invalid shortcut.');
    if (accelerator === registeredAccelerator) return { success: true };
    if (!globalShortcut.register(accelerator, toggleWindow)) {
      return { success: false, message: 'That shortcut is already used by another application.' };
    }
    if (registeredAccelerator) globalShortcut.unregister(registeredAccelerator);
    registeredAccelerator = accelerator;
    preferences.saveShortcut(accelerator, display);
    return { success: true };
  });
  ipcMain.handle('window:toggle-compact', (event) => {
    if (!isTrustedFrame(event.senderFrame)) throw new Error('Untrusted IPC sender');
    return toggleCompactWindow();
  });
}

function toggleCompactWindow(): boolean {
  if (!mainWindow) return false;
  if (isCompact) {
    isCompact = false;
    mainWindow.setResizable(true);
    if (expandedBounds) mainWindow.setBounds(expandedBounds, true);
  } else {
    expandedBounds = mainWindow.getBounds();
    isCompact = true;
    mainWindow.setResizable(false);
    const width = mainWindow.getBounds().width;
    mainWindow.setSize(Math.max(500, Math.min(width, 660)), 52, true);
  }
  return isCompact;
}

async function executeRequest(request: RequestDraft, signal: AbortSignal): Promise<ResponseSnapshot> {
  const startedAt = performance.now();
  try {
    const url = buildURL(request);
    if (!['http:', 'https:'].includes(new URL(url).protocol)) throw new Error('Use a complete HTTP or HTTPS URL.');
    if (request.bodyKind === 'JSON' && request.body.trim()) JSON.parse(request.body);
    const headers = requestHeaders(request);
    const response = await fetch(url, {
      method: request.method,
      headers,
      body: request.bodyKind === 'None' || !request.body ? undefined : request.body,
      redirect: 'follow',
      signal,
    });
    const bytes = Buffer.from(await response.arrayBuffer());
    return {
      id: crypto.randomUUID(),
      statusCode: response.status,
      reasonPhrase: response.statusText,
      headers: Object.fromEntries(response.headers.entries()),
      bodyText: bytes.toString('utf8'),
      bodyBase64: bytes.toString('base64'),
      mimeType: response.headers.get('content-type') ?? undefined,
      durationMs: performance.now() - startedAt,
      receivedByteCount: bytes.byteLength,
      wasCancelled: false,
      receivedAt: new Date().toISOString(),
    };
  } catch (error) {
    const wasCancelled = error instanceof Error && error.name === 'AbortError';
    return {
      id: crypto.randomUUID(),
      reasonPhrase: '',
      headers: {},
      bodyText: '',
      bodyBase64: '',
      durationMs: performance.now() - startedAt,
      receivedByteCount: 0,
      errorDescription: wasCancelled ? 'Request cancelled' : error instanceof Error ? error.message : 'Request failed',
      wasCancelled,
      receivedAt: new Date().toISOString(),
    };
  }
}

function requestHeaders(request: RequestDraft): Record<string, string> {
  const headers = enabledHeaders(request);
  const hasContentType = Object.keys(headers).some((name) => name.toLowerCase() === 'content-type');
  if (request.bodyKind === 'JSON' && request.body && !hasContentType) headers['Content-Type'] = 'application/json';
  if (request.authentication.kind === 'Bearer' && request.authentication.secret) {
    headers.Authorization = `Bearer ${request.authentication.secret}`;
  } else if (request.authentication.kind === 'Basic') {
    headers.Authorization = `Basic ${Buffer.from(`${request.authentication.username}:${request.authentication.secret}`).toString('base64')}`;
  }
  return headers;
}

app.whenReady().then(() => {
  if (process.platform === 'darwin') app.dock?.hide();
  session.defaultSession.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false));
  const userData = app.getPath('userData');
  const wasmPath = app.isPackaged
    ? path.join(process.resourcesPath, 'sql-wasm.wasm')
    : path.join(app.getAppPath(), 'node_modules/sql.js/dist/sql-wasm.wasm');
  void HistoryStore.open(path.join(userData, 'history.sqlite'), wasmPath).then((history) => {
    const preferences = new PreferencesStore(path.join(userData, 'preferences.json'));
    registerIPC(history, new CredentialVault(path.join(userData, 'credentials.enc.json')), preferences);
    mainWindow = createWindow();
    tray = createTray();
    if (globalShortcut.register(preferences.shortcut.shortcut, toggleWindow)) {
      registeredAccelerator = preferences.shortcut.shortcut;
    }
  }).catch((error: unknown) => {
    console.error('Curlman could not initialize local storage.', error);
    app.quit();
  });
});

app.on('before-quit', () => {
  isQuitting = true;
  globalShortcut.unregisterAll();
  tray?.destroy();
  tray = null;
});

app.on('window-all-closed', () => {});
