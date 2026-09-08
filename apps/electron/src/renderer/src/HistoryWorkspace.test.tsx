import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { HistoryEntry } from '../../shared/models';
import { HistoryWorkspace } from './HistoryWorkspace';

describe('HistoryWorkspace', () => {
  it('supports one-click rerun and inline rename', () => {
    const entry = historyEntry();
    const onRename = vi.fn();
    const onRerun = vi.fn();
    render(
      <HistoryWorkspace
        entries={[entry]}
        onRestore={vi.fn()}
        onTogglePin={vi.fn()}
        onRename={onRename}
        onRerun={onRerun}
        onDelete={vi.fn()}
        onClear={vi.fn()}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Run' }));
    expect(onRerun).toHaveBeenCalledWith(entry);

    fireEvent.click(screen.getByRole('button', { name: 'Rename request' }));
    fireEvent.change(screen.getByRole('textbox', { name: 'History name' }), { target: { value: 'Team webhook' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(onRename).toHaveBeenCalledWith(entry.id, 'Team webhook');
  });
});

function historyEntry(): HistoryEntry {
  return {
    id: 'history-1',
    startedAt: '2026-09-08T08:00:00.000Z',
    displayName: '',
    request: {
      id: 'request-1',
      name: '',
      method: 'GET',
      urlString: 'https://example.com/items',
      queryItems: [],
      headers: [],
      bodyKind: 'None',
      body: '',
      authentication: { kind: 'None', username: '', secret: '' },
    },
    response: {
      id: 'response-1',
      statusCode: 200,
      reasonPhrase: 'OK',
      headers: { 'content-type': 'application/json' },
      bodyText: '{"ok":true}',
      bodyBase64: 'eyJvayI6dHJ1ZX0=',
      mimeType: 'application/json',
      durationMs: 42,
      receivedByteCount: 11,
      wasCancelled: false,
      receivedAt: '2026-09-08T08:00:00.000Z',
    },
    isPinned: false,
  };
}
