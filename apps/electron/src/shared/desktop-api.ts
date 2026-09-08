import type { CurlImportResult, HistoryEntry, RequestDraft, ResponseSnapshot } from './models';

export interface DesktopAPI {
  getPlatform: () => Promise<NodeJS.Platform>;
  hideWindow: () => Promise<void>;
  getVersion: () => Promise<string>;
  onFocusCommandInput: (listener: () => void) => () => void;
  onTrayAction: (listener: (action: 'new-request' | 'history' | 'settings') => void) => () => void;
  importCurl: (command: string) => Promise<CurlImportResult>;
  copyAsCurl: (request: RequestDraft) => Promise<string>;
  copyText: (text: string) => Promise<void>;
  saveResponse: (bodyBase64: string, suggestedName: string) => Promise<boolean>;
  executeRequest: (request: RequestDraft) => Promise<ResponseSnapshot>;
  cancelRequest: () => Promise<void>;
  listHistory: () => Promise<HistoryEntry[]>;
  restoreHistory: (id: string) => Promise<HistoryEntry>;
  toggleHistoryPin: (id: string) => Promise<void>;
  renameHistory: (id: string, name: string) => Promise<void>;
  deleteHistory: (id: string) => Promise<void>;
  clearHistory: () => Promise<void>;
  getShortcut: () => Promise<{ accelerator: string; display: string; registered: boolean }>;
  setShortcut: (accelerator: string, display: string) => Promise<{ success: boolean; message?: string }>;
  toggleCompact: () => Promise<boolean>;
}

declare global {
  interface Window {
    curlman: DesktopAPI;
  }
}
