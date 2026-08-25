import type { WebFrameMain } from 'electron';

export function isTrustedFrame(frame: WebFrameMain | null): boolean {
  if (!frame) return false;
  const frameURL = new URL(frame.url);
  if (frameURL.protocol === 'file:') return true;
  return frameURL.hostname === 'localhost' && frameURL.protocol === 'http:';
}
