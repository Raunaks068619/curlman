import fs from 'node:fs';
import path from 'node:path';

interface Preferences {
  shortcut: string;
  shortcutDisplay: string;
}

const defaultPreferences: Preferences = {
  shortcut: process.platform === 'darwin' ? 'Command+Shift+C' : 'Control+Shift+C',
  shortcutDisplay: process.platform === 'darwin' ? '⌘⇧C' : 'Ctrl+Shift+C',
};

export class PreferencesStore {
  private values: Preferences;

  constructor(private readonly filePath: string) {
    this.values = this.load();
  }

  get shortcut(): Preferences {
    return { ...this.values };
  }

  saveShortcut(shortcut: string, shortcutDisplay: string): void {
    this.values = { shortcut, shortcutDisplay };
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    const temporaryPath = `${this.filePath}.tmp`;
    fs.writeFileSync(temporaryPath, JSON.stringify(this.values, null, 2), { mode: 0o600 });
    fs.renameSync(temporaryPath, this.filePath);
  }

  private load(): Preferences {
    if (!fs.existsSync(this.filePath)) return defaultPreferences;
    try {
      const stored = JSON.parse(fs.readFileSync(this.filePath, 'utf8')) as Partial<Preferences>;
      if (stored.shortcut && stored.shortcutDisplay) return { shortcut: stored.shortcut, shortcutDisplay: stored.shortcutDisplay };
    } catch {
      // Invalid preferences fall back to a working default.
    }
    return defaultPreferences;
  }
}
