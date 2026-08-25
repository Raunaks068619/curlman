import { useCallback, useEffect, useMemo, useState } from 'react';
import { createEmptyRequest, HTTPMethods, type HistoryEntry, type RequestDraft, type ResponseSnapshot } from '../../shared/models';
import { HistoryWorkspace } from './HistoryWorkspace';
import { RequestWorkspace, type RequestSection } from './RequestWorkspace';
import { ResponseWorkspace } from './ResponseWorkspace';
import { ShortcutSettings } from './ShortcutSettings';

type TopTab = 'Request' | 'Response' | 'History' | 'Settings';

export function App() {
  const [draft, setDraft] = useState<RequestDraft>(createEmptyRequest);
  const [response, setResponse] = useState<ResponseSnapshot>();
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [topTab, setTopTab] = useState<TopTab>('Request');
  const [requestSection, setRequestSection] = useState<RequestSection>('Body');
  const [warnings, setWarnings] = useState<string[]>([]);
  const [error, setError] = useState<string>();
  const [isSending, setIsSending] = useState(false);
  const [didCopy, setDidCopy] = useState(false);
  const [isCompact, setIsCompact] = useState(false);
  const [platform, setPlatform] = useState<NodeJS.Platform>('darwin');

  const refreshHistory = useCallback(async () => {
    setHistory(await window.curlman.listHistory());
  }, []);

  useEffect(() => {
    void refreshHistory();
    void window.curlman.getPlatform().then(setPlatform);
  }, [refreshHistory]);

  const expand = useCallback(async () => {
    if (!isCompact) return;
    await window.curlman.toggleCompact();
    setIsCompact(false);
  }, [isCompact]);

  const importCurl = useCallback(async (command: string) => {
    try {
      await expand();
      const result = await window.curlman.importCurl(command.trim().replace(/^\$\s+/, ''));
      setDraft(result.request);
      setWarnings(result.warnings);
      setResponse(undefined);
      setTopTab('Request');
      setError(undefined);
    } catch (cause) {
      setError(messageFrom(cause));
    }
  }, [expand]);

  const send = useCallback(async () => {
    if (isSending) {
      await window.curlman.cancelRequest();
      return;
    }
    const validationError = validateRequest(draft);
    if (validationError) {
      setError(validationError);
      return;
    }
    setError(undefined);
    setIsSending(true);
    try {
      const result = await window.curlman.executeRequest(draft);
      setResponse(result);
      await refreshHistory();
      await expand();
      setTopTab('Response');
    } catch (cause) {
      setError(messageFrom(cause));
    } finally {
      setIsSending(false);
    }
  }, [draft, expand, isSending, refreshHistory]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
        event.preventDefault();
        void send();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [send]);

  const availableTabs = useMemo<TopTab[]>(
    () => (response ? ['Request', 'Response', 'History', 'Settings'] : ['Request', 'History', 'Settings']),
    [response],
  );

  const copyAsCurl = async () => {
    try {
      await window.curlman.copyAsCurl(draft);
      setDidCopy(true);
      window.setTimeout(() => setDidCopy(false), 1600);
      setError(undefined);
    } catch (cause) {
      setError(messageFrom(cause));
    }
  };

  const restoreHistory = async (entry: HistoryEntry, openResponse: boolean) => {
    try {
      const restored = await window.curlman.restoreHistory(entry.id);
      setDraft(restored.request);
      setResponse(restored.response);
      setTopTab(openResponse ? 'Response' : 'Request');
      setError(undefined);
    } catch (cause) {
      setError(messageFrom(cause));
    }
  };

  const toggleHistoryPin = async (id: string) => {
    await window.curlman.toggleHistoryPin(id);
    await refreshHistory();
  };

  const deleteHistory = async (id: string) => {
    await window.curlman.deleteHistory(id);
    await refreshHistory();
  };

  return (
    <main className={`shell platform-${platform} ${isCompact ? 'compact' : ''}`}>
      <header className="titlebar">
        <div className="brand">Curlman</div>
        <div className="window-actions">
          <button className="window-action" type="button" onClick={() => setTopTab('Settings')} aria-label="Open settings">⚙︎</button>
          <button
            className="window-action"
            type="button"
            onClick={() => void window.curlman.toggleCompact().then(setIsCompact)}
            aria-label={isCompact ? 'Expand Curlman' : 'Minimize Curlman'}
          >{isCompact ? '▢' : '−'}</button>
          <button className="window-action close-action" type="button" onClick={() => void window.curlman.hideWindow()} aria-label="Hide Curlman">×</button>
        </div>
      </header>

      <section className="request-command" aria-label="Request command">
        <select
          aria-label="HTTP method"
          value={draft.method}
          onChange={(event) => setDraft({ ...draft, method: event.target.value as RequestDraft['method'] })}
        >
          {HTTPMethods.map((method) => <option key={method}>{method}</option>)}
        </select>
        <input
          aria-label="Request URL"
          value={draft.urlString}
          placeholder="Enter URL or paste a cURL request"
          spellCheck={false}
          onChange={(event) => setDraft({ ...draft, urlString: event.target.value })}
          onPaste={(event) => {
            const pasted = event.clipboardData.getData('text');
            if (isCurlCommand(pasted)) {
              event.preventDefault();
              void importCurl(pasted);
            }
          }}
          autoFocus
        />
        <button className="secondary-action" type="button" onClick={() => void copyAsCurl()}>{didCopy ? 'Copied' : 'Copy cURL'}</button>
        <button
          className="compact-expand"
          type="button"
          onClick={() => void window.curlman.toggleCompact().then(setIsCompact)}
          aria-label="Expand Curlman"
        >▢</button>
        <button className="primary-action" type="button" onClick={() => void send()}>{isSending ? 'Cancel' : 'Send'} <kbd>{platform === 'darwin' ? '⌘↵' : 'Ctrl+↵'}</kbd></button>
      </section>

      <nav className="top-tabs" aria-label="Workspace">
        {availableTabs.map((tab) => (
          <button key={tab} type="button" className={topTab === tab ? 'active' : ''} onClick={() => setTopTab(tab)}>
            {tab}{tab === 'Response' && response?.statusCode ? ` ${response.statusCode}` : ''}
          </button>
        ))}
      </nav>

      {(error || warnings.length > 0) && (
        <div className="message-stack" role="status">
          {error && <div className="inline-error">{error}</div>}
          {warnings.map((warning) => <div className="inline-warning" key={warning}>{warning}</div>)}
        </div>
      )}

      {topTab === 'Request' && (
        <RequestWorkspace
          draft={draft}
          section={requestSection}
          onSectionChange={setRequestSection}
          onChange={setDraft}
          onError={setError}
        />
      )}
      {topTab === 'Response' && response && <ResponseWorkspace response={response} />}
      {topTab === 'History' && (
        <HistoryWorkspace
          entries={history}
          onRestore={(entry, openResponse) => void restoreHistory(entry, openResponse)}
          onTogglePin={(id) => void toggleHistoryPin(id)}
          onDelete={(id) => void deleteHistory(id)}
          onClear={() => void window.curlman.clearHistory().then(refreshHistory)}
        />
      )}
      {topTab === 'Settings' && <ShortcutSettings platform={platform} />}
    </main>
  );
}

function isCurlCommand(value: string): boolean {
  return /^(\$\s+)?(\/usr\/bin\/)?curl\s/.test(value.trim());
}

function validateRequest(request: RequestDraft): string | undefined {
  try {
    const url = new URL(request.urlString);
    if (!['http:', 'https:'].includes(url.protocol)) return 'Use a complete HTTP or HTTPS URL.';
  } catch {
    return 'Enter a complete HTTP or HTTPS URL.';
  }
  if (request.bodyKind === 'JSON' && request.body.trim()) {
    try {
      JSON.parse(request.body);
    } catch {
      return 'The JSON body is invalid. Format or correct it before sending.';
    }
  }
  return undefined;
}

function messageFrom(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}
