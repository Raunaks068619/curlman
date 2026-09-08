import { useState } from 'react';
import type { HistoryEntry } from '../../shared/models';

interface HistoryWorkspaceProps {
  entries: HistoryEntry[];
  onRestore: (entry: HistoryEntry, openResponse: boolean) => void;
  onTogglePin: (id: string) => void;
  onRename: (id: string, name: string) => void;
  onRerun: (entry: HistoryEntry) => void;
  onDelete: (id: string) => void;
  onClear: () => void;
}

export function HistoryWorkspace({ entries, onRestore, onTogglePin, onRename, onRerun, onDelete, onClear }: HistoryWorkspaceProps) {
  const [query, setQuery] = useState('');
  const [renamingID, setRenamingID] = useState<string>();
  const [nextName, setNextName] = useState('');
  const filtered = entries.filter((entry) => {
    const haystack = `${entry.request.method} ${entry.request.urlString} ${entry.response.statusCode ?? ''}`.toLowerCase();
    return haystack.includes(query.trim().toLowerCase());
  });

  return (
    <section className="workspace history-workspace">
      <div className="history-tools">
        <input type="search" placeholder="Search history" value={query} onChange={(event) => setQuery(event.target.value)} />
        {entries.length > 0 && <button type="button" onClick={onClear}>Clear history</button>}
      </div>
      {filtered.length === 0 ? (
        <div className="quiet-state">{entries.length === 0 ? 'Requests appear here automatically after you send them.' : 'No history matches this search.'}</div>
      ) : (
        <div className="history-list">
          {filtered.map((entry) => (
            <article key={entry.id}>
              {renamingID === entry.id ? (
                <form className="history-rename" onSubmit={(event) => {
                  event.preventDefault();
                  onRename(entry.id, nextName);
                  setRenamingID(undefined);
                }}>
                  <input autoFocus aria-label="History name" value={nextName} placeholder="Request name" onChange={(event) => setNextName(event.target.value)} />
                  <button type="submit">Save</button>
                  <button type="button" onClick={() => setRenamingID(undefined)}>Cancel</button>
                </form>
              ) : (
                <button type="button" onClick={() => onRestore(entry, false)}>
                  <strong>{entry.request.method}</strong><span className="history-url" title={entry.request.urlString}>{entry.displayName || entry.request.urlString}</span>
                  <span className={entry.response.statusCode && entry.response.statusCode < 400 ? 'success' : 'failure'}>{entry.response.statusCode ?? 'Error'}</span>
                  <time dateTime={entry.response.receivedAt}>{new Date(entry.response.receivedAt).toLocaleString()}</time>
                </button>
              )}
              {renamingID !== entry.id && <div className="history-actions">
                <button type="button" onClick={() => onTogglePin(entry.id)} aria-label={entry.isPinned ? 'Unpin request' : 'Pin request'}>{entry.isPinned ? '★' : '☆'}</button>
                <button type="button" onClick={() => onRerun(entry)}>Run</button>
                <button type="button" onClick={() => onRestore(entry, true)}>Response</button>
                <button type="button" onClick={() => {
                  setNextName(entry.displayName);
                  setRenamingID(entry.id);
                }} aria-label="Rename request">Rename</button>
                <button type="button" onClick={() => onDelete(entry.id)} aria-label="Delete request">×</button>
              </div>}
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
