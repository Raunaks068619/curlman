import { useMemo, useState } from 'react';
import type { ResponseSnapshot } from '../../shared/models';
import { CodeEditor } from './CodeEditor';

type ResponseSection = 'Pretty' | 'Raw' | 'Headers';

export function ResponseWorkspace({ response }: { response: ResponseSnapshot }) {
  const [section, setSection] = useState<ResponseSection>('Pretty');
  const prettyBody = useMemo(() => {
    try { return JSON.stringify(JSON.parse(response.bodyText), null, 2); }
    catch { return response.bodyText; }
  }, [response.bodyText]);
  const isJSON = response.mimeType?.includes('json') || /^[\s]*[{[]/.test(response.bodyText);
  const statusClass = response.statusCode && response.statusCode < 400 ? 'success' : 'failure';

  return (
    <section className="workspace response-workspace">
      <div className="response-summary">
        <strong className={statusClass}>{response.statusCode ? `${response.statusCode} ${response.reasonPhrase}` : response.errorDescription}</strong>
        <span>{(response.durationMs / 1000).toFixed(2)} s</span>
        <span>{formatBytes(response.receivedByteCount)}</span>
        <time dateTime={response.receivedAt}>{new Date(response.receivedAt).toLocaleString()}</time>
      </div>
      <div className="section-toolbar">
        <nav className="section-tabs" aria-label="Response sections">
          {(['Pretty', 'Raw', 'Headers'] as const).map((item) => (
            <button key={item} type="button" className={section === item ? 'active' : ''} onClick={() => setSection(item)}>{item}{item === 'Headers' ? ` ${Object.keys(response.headers).length}` : ''}</button>
          ))}
        </nav>
      </div>
      {response.errorDescription && !response.bodyText ? <div className="transport-error">{response.errorDescription}</div> : null}
      {section === 'Pretty' && response.bodyText && <CodeEditor label="Formatted response" value={prettyBody} readOnly language={isJSON ? 'json' : 'raw'} />}
      {section === 'Raw' && <CodeEditor label="Raw response" value={response.bodyText} readOnly language="raw" />}
      {section === 'Headers' && <div className="header-list">{Object.entries(response.headers).map(([name, value]) => <div key={name}><strong>{name}</strong><span>{value}</span></div>)}</div>}
    </section>
  );
}

function formatBytes(count: number): string {
  if (count < 1024) return `${count} bytes`;
  return `${(count / 1024).toFixed(1)} KB`;
}
