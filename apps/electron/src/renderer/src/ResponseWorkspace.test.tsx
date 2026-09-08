import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import type { DesktopAPI } from '../../shared/desktop-api';
import type { ResponseSnapshot } from '../../shared/models';
import { ResponseWorkspace } from './ResponseWorkspace';

describe('ResponseWorkspace', () => {
  it('copies the content currently shown and saves the original response', () => {
    window.curlman = {
      copyText: vi.fn().mockResolvedValue(undefined),
      saveResponse: vi.fn().mockResolvedValue(true),
    } as unknown as DesktopAPI;
    render(<ResponseWorkspace response={response()} />);

    fireEvent.click(screen.getByRole('button', { name: 'Copy' }));
    expect(window.curlman.copyText).toHaveBeenCalledWith('{\n  "ok": true\n}');

    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(window.curlman.saveResponse).toHaveBeenCalledWith('eyJvayI6dHJ1ZX0=', 'response.json');
  });
});

function response(): ResponseSnapshot {
  return {
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
  };
}
