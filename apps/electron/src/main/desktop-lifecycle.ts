import type { Rectangle } from 'electron';

export const compactHeight = 52;
export const minimumCompactWidth = 500;
export const maximumCompactWidth = 660;

export function compactBounds(bounds: Rectangle): Pick<Rectangle, 'width' | 'height'> {
  return {
    width: Math.max(minimumCompactWidth, Math.min(bounds.width, maximumCompactWidth)),
    height: compactHeight,
  };
}

export function shouldHideOnClose(hasTray: boolean, hasGlobalShortcut: boolean): boolean {
  return hasTray || hasGlobalShortcut;
}
