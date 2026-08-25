import { useState } from 'react';
import type { HistoryEntry } from '../../shared/models';

interface HistoryWorkspaceProps {
  entries: HistoryEntry[];
  onRestore: (entry: HistoryEntry, openResponse: boolean) => void;
  onTogglePin: (id: string) => void;
  onDelete: (id: string) => void;
  onClear: () => void;
}

export function HistoryWorkspace({ entries, onRestore, onTogglePin, onDelete, onClear }: HistoryWorkspaceProps) {
  const [query, setQuery] = useState('');
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
              <button type="button" onClick={() => onRestore(entry, false)}>
                <strong>{entry.request.method}</strong><span className="history-url">{entry.request.urlString}</span>
                <span className={entry.response.statusCode && entry.response.statusCode < 400 ? 'success' : 'failure'}>{entry.response.statusCode ?? 'Error'}</span>
                <time dateTime={entry.response.receivedAt}>{new Date(entry.response.receivedAt).toLocaleString()}</time>
              </button>
              <div className="history-actions">
                <button type="button" onClick={() => onTogglePin(entry.id)} aria-label={entry.isPinned ? 'Unpin request' : 'Pin request'}>{entry.isPinned ? '★' : '☆'}</button>
                <button type="button" onClick={() => onRestore(entry, true)}>Response</button>
                <button type="button" onClick={() => onDelete(entry.id)} aria-label="Delete request">×</button>
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
