import { describe, expect, it } from 'vitest';
import { compactBounds, shouldHideOnClose } from './desktop-lifecycle';

describe('cross-platform desktop lifecycle', () => {
  it('keeps compact sizing independent from extreme expanded widths', () => {
    expect(compactBounds({ x: 0, y: 0, width: 420, height: 900 })).toEqual({ width: 500, height: 52 });
    expect(compactBounds({ x: 0, y: 0, width: 580, height: 900 })).toEqual({ width: 580, height: 52 });
    expect(compactBounds({ x: 0, y: 0, width: 1200, height: 900 })).toEqual({ width: 660, height: 52 });
  });

  it('hides only when the running app has a reliable way to reopen', () => {
    expect(shouldHideOnClose(true, false)).toBe(true);
    expect(shouldHideOnClose(false, true)).toBe(true);
    expect(shouldHideOnClose(false, false)).toBe(false);
  });
});
