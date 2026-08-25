import { createKeyValueItem, type KeyValueItem } from '../../shared/models';

interface KeyValueEditorProps {
  label: string;
  items: KeyValueItem[];
  onChange: (items: KeyValueItem[]) => void;
}

export function KeyValueEditor({ label, items, onChange }: KeyValueEditorProps) {
  const update = (id: string, change: Partial<KeyValueItem>) => {
    onChange(items.map((item) => (item.id === id ? { ...item, ...change } : item)));
  };

  return (
    <section className="key-value-editor" aria-label={label}>
      <div className="table-heading"><span>Enabled</span><span>Name</span><span>Value</span><span /></div>
      {items.map((item) => (
        <div className="key-value-row" key={item.id}>
          <input type="checkbox" checked={item.isEnabled} onChange={(event) => update(item.id, { isEnabled: event.target.checked })} aria-label={`Enable ${item.name || 'row'}`} />
          <input value={item.name} placeholder="Name" onChange={(event) => update(item.id, { name: event.target.value })} />
          <input value={item.value} placeholder="Value" onChange={(event) => update(item.id, { value: event.target.value })} />
          <button type="button" className="icon-action" onClick={() => onChange(items.filter((candidate) => candidate.id !== item.id))} aria-label="Remove row">×</button>
        </div>
      ))}
      <button className="add-row" type="button" onClick={() => onChange([...items, createKeyValueItem()])}>＋ Add row</button>
    </section>
  );
}
