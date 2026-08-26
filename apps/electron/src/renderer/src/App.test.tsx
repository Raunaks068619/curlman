import { act, render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { App } from './App';

describe('Curlman shell', () => {
  let focusCommandInput = () => undefined;
  let runTrayAction: (action: 'new-request' | 'history' | 'settings') => void = () => undefined;

  beforeEach(() => {
    window.curlman = {
      getPlatform: vi.fn().mockResolvedValue('linux'),
      getVersion: vi.fn().mockResolvedValue('0.2.0'),
      onFocusCommandInput: vi.fn((listener) => {
        focusCommandInput = listener;
        return () => undefined;
      }),
      onTrayAction: vi.fn((listener) => {
        runTrayAction = listener;
        return () => undefined;
      }),
      hideWindow: vi.fn().mockResolvedValue(undefined),
      importCurl: vi.fn(),
      copyAsCurl: vi.fn(),
      executeRequest: vi.fn(),
      cancelRequest: vi.fn().mockResolvedValue(undefined),
      listHistory: vi.fn().mockResolvedValue([]),
      restoreHistory: vi.fn(),
      toggleHistoryPin: vi.fn().mockResolvedValue(undefined),
      deleteHistory: vi.fn().mockResolvedValue(undefined),
      clearHistory: vi.fn().mockResolvedValue(undefined),
      getShortcut: vi.fn().mockResolvedValue({ accelerator: 'Control+Shift+C', display: 'Ctrl+Shift+C', registered: true }),
      setShortcut: vi.fn().mockResolvedValue({ success: true }),
      toggleCompact: vi.fn().mockResolvedValue(true),
    };
  });

  it('starts in the request workspace without an empty response tab', async () => {
    render(<App />);

    expect(screen.getByRole('navigation', { name: 'Workspace' })).toHaveTextContent('Request');
    expect(screen.queryByRole('button', { name: 'Response' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Send/ })).toBeInTheDocument();
  });

  it('returns focus to the command input whenever the window opens', () => {
    render(<App />);
    const input = screen.getByRole('textbox', { name: 'Request URL' });
    screen.getByRole('button', { name: /Send/ }).focus();
    expect(input).not.toHaveFocus();

    act(() => focusCommandInput());

    expect(input).toHaveFocus();
  });

  it('opens tray destinations without requiring the main navigation', () => {
    render(<App />);

    act(() => runTrayAction('history'));
    expect(screen.getByRole('navigation', { name: 'Workspace' })).toHaveTextContent('History');

    act(() => runTrayAction('settings'));
    expect(screen.getByRole('heading', { name: 'Global shortcut' })).toBeInTheDocument();
  });
});
