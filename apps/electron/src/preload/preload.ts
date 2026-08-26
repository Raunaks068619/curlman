import { contextBridge, ipcRenderer } from 'electron';
import type { DesktopAPI } from '../shared/desktop-api';
import type { CurlImportResult, HistoryEntry, RequestDraft, ResponseSnapshot } from '../shared/models';

const api: DesktopAPI = {
  getPlatform: () => ipcRenderer.invoke('desktop:get-platform') as Promise<NodeJS.Platform>,
  getVersion: () => ipcRenderer.invoke('desktop:get-version') as Promise<string>,
  onFocusCommandInput: (listener) => {
    const handleFocus = () => listener();
    ipcRenderer.on('window:focus-command-input', handleFocus);
    return () => ipcRenderer.removeListener('window:focus-command-input', handleFocus);
  },
  hideWindow: () => ipcRenderer.invoke('desktop:hide-window') as Promise<void>,
  importCurl: (command: string) => ipcRenderer.invoke('request:import-curl', command) as Promise<CurlImportResult>,
  copyAsCurl: (request: RequestDraft) => ipcRenderer.invoke('request:copy-curl', request) as Promise<string>,
  executeRequest: (request: RequestDraft) => ipcRenderer.invoke('request:execute', request) as Promise<ResponseSnapshot>,
  cancelRequest: () => ipcRenderer.invoke('request:cancel') as Promise<void>,
  listHistory: () => ipcRenderer.invoke('history:list') as Promise<HistoryEntry[]>,
  restoreHistory: (id: string) => ipcRenderer.invoke('history:restore', id) as Promise<HistoryEntry>,
  toggleHistoryPin: (id: string) => ipcRenderer.invoke('history:toggle-pin', id) as Promise<void>,
  deleteHistory: (id: string) => ipcRenderer.invoke('history:delete', id) as Promise<void>,
  clearHistory: () => ipcRenderer.invoke('history:clear') as Promise<void>,
  getShortcut: () => ipcRenderer.invoke('settings:get-shortcut') as Promise<{ accelerator: string; display: string; registered: boolean }>,
  setShortcut: (accelerator: string, display: string) => ipcRenderer.invoke('settings:set-shortcut', accelerator, display) as Promise<{ success: boolean; message?: string }>,
  toggleCompact: () => ipcRenderer.invoke('window:toggle-compact') as Promise<boolean>,
};

contextBridge.exposeInMainWorld('curlman', api);
