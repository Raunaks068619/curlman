import { useEffect, useState } from 'react';

interface ShortcutSettingsProps {
  platform: NodeJS.Platform;
}

interface ShortcutState {
  accelerator: string;
  display: string;
  registered: boolean;
}

export function ShortcutSettings({ platform }: ShortcutSettingsProps) {
  const [shortcut, setShortcut] = useState<ShortcutState>();
  const [isRecording, setIsRecording] = useState(false);
  const [message, setMessage] = useState<string>();

  useEffect(() => {
    void window.curlman.getShortcut().then(setShortcut);
  }, []);

  const record = async (event: React.KeyboardEvent<HTMLButtonElement>) => {
    if (!isRecording) return;
    event.preventDefault();
    event.stopPropagation();
    if (event.key === 'Escape') {
      setIsRecording(false);
      setMessage(undefined);
      return;
    }
    const candidate = shortcutFromEvent(event, platform);
    if (!candidate) {
      setMessage('Use Command, Control, or Alt with another key.');
      return;
    }
    const result = await window.curlman.setShortcut(candidate.accelerator, candidate.display);
    if (!result.success) {
      setMessage(result.message ?? 'That shortcut could not be registered.');
      return;
    }
    setShortcut({ ...candidate, registered: true });
    setIsRecording(false);
    setMessage('Shortcut updated.');
  };

  return (
    <section className="workspace settings-workspace" aria-label="Settings">
      <div className="settings-group">
        <div>
          <h2>Global shortcut</h2>
          <p>Open or hide Curlman from anywhere. Your previous shortcut remains active if a new one conflicts.</p>
        </div>
        <button
          className={`shortcut-recorder ${isRecording ? 'recording' : ''}`}
          type="button"
          onClick={() => {
            setIsRecording(true);
            setMessage('Press your shortcut. Escape cancels.');
          }}
          onKeyDown={(event) => void record(event)}
        >
          {isRecording ? 'Press shortcut…' : shortcut?.display ?? 'Loading…'}
        </button>
      </div>
      {shortcut && !shortcut.registered && (
        <p className="settings-message failure">The saved shortcut is currently unavailable. Choose another one.</p>
      )}
      {message && <p className="settings-message" role="status">{message}</p>}
    </section>
  );
}

function shortcutFromEvent(event: React.KeyboardEvent, platform: NodeJS.Platform): Omit<ShortcutState, 'registered'> | undefined {
  const key = normalizedKey(event.key);
  if (!key || ['Meta', 'Control', 'Alt', 'Shift'].includes(key)) return undefined;
  if (!event.metaKey && !event.ctrlKey && !event.altKey) return undefined;

  const modifiers: string[] = [];
  const display: string[] = [];
  if (event.metaKey) {
    modifiers.push('Command');
    display.push(platform === 'darwin' ? '⌘' : 'Meta+');
  }
  if (event.ctrlKey) {
    modifiers.push('Control');
    display.push(platform === 'darwin' ? '⌃' : 'Ctrl+');
  }
  if (event.altKey) {
    modifiers.push('Alt');
    display.push(platform === 'darwin' ? '⌥' : 'Alt+');
  }
  if (event.shiftKey) {
    modifiers.push('Shift');
    display.push(platform === 'darwin' ? '⇧' : 'Shift+');
  }
  return {
    accelerator: [...modifiers, key].join('+'),
    display: `${display.join('')}${displayKey(key)}`,
  };
}

function normalizedKey(value: string): string | undefined {
  if (value.length === 1 && /[a-z0-9]/i.test(value)) return value.toUpperCase();
  const namedKeys: Record<string, string> = {
    ' ': 'Space',
    ArrowUp: 'Up',
    ArrowDown: 'Down',
    ArrowLeft: 'Left',
    ArrowRight: 'Right',
    Enter: 'Enter',
    Backspace: 'Backspace',
    Delete: 'Delete',
    Tab: 'Tab',
  };
  if (/^F([1-9]|1[0-9]|2[0-4])$/.test(value)) return value;
  return namedKeys[value];
}

function displayKey(key: string): string {
  return { Up: '↑', Down: '↓', Left: '←', Right: '→', Enter: '↵', Backspace: '⌫', Delete: '⌦', Space: 'Space', Tab: '⇥' }[key] ?? key;
}
