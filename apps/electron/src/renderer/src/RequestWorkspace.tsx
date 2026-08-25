import { BodyKinds, type RequestDraft } from '../../shared/models';
import { CodeEditor } from './CodeEditor';
import { KeyValueEditor } from './KeyValueEditor';

export type RequestSection = 'Body' | 'Params' | 'Headers' | 'Auth';
const sections: RequestSection[] = ['Body', 'Params', 'Headers', 'Auth'];

interface RequestWorkspaceProps {
  draft: RequestDraft;
  section: RequestSection;
  onSectionChange: (section: RequestSection) => void;
  onChange: (draft: RequestDraft) => void;
  onError: (message?: string) => void;
}

export function RequestWorkspace({ draft, section, onSectionChange, onChange, onError }: RequestWorkspaceProps) {
  const formatJSON = () => {
    try {
      onChange({ ...draft, body: JSON.stringify(JSON.parse(draft.body), null, 2) });
      onError(undefined);
    } catch {
      onError('The JSON body is invalid and could not be formatted.');
    }
  };

  return (
    <section className="workspace">
      <div className="section-toolbar">
        <nav className="section-tabs" aria-label="Request sections">
          {sections.map((item) => (
            <button key={item} type="button" className={section === item ? 'active' : ''} onClick={() => onSectionChange(item)}>
              {item}{item === 'Headers' && draft.headers.filter((header) => header.name).length > 0 ? ` ${draft.headers.filter((header) => header.name).length}` : ''}
            </button>
          ))}
        </nav>
        {section === 'Body' && (
          <div className="toolbar-actions">
            <select value={draft.bodyKind} onChange={(event) => onChange({ ...draft, bodyKind: event.target.value as RequestDraft['bodyKind'] })} aria-label="Body type">
              {BodyKinds.map((kind) => <option key={kind}>{kind}</option>)}
            </select>
            {draft.bodyKind === 'JSON' && <button type="button" onClick={formatJSON}>Format</button>}
          </div>
        )}
      </div>

      {section === 'Body' && draft.bodyKind !== 'None' && (
        <CodeEditor label="Request body" value={draft.body} language={draft.bodyKind === 'JSON' ? 'json' : 'raw'} onChange={(body) => onChange({ ...draft, body })} />
      )}
      {section === 'Body' && draft.bodyKind === 'None' && <div className="quiet-state">This request has no body.</div>}
      {section === 'Params' && <KeyValueEditor label="Query parameters" items={draft.queryItems} onChange={(queryItems) => onChange({ ...draft, queryItems })} />}
      {section === 'Headers' && <KeyValueEditor label="Request headers" items={draft.headers} onChange={(headers) => onChange({ ...draft, headers })} />}
      {section === 'Auth' && (
        <div className="auth-form">
          <label>Authentication<select value={draft.authentication.kind} onChange={(event) => onChange({ ...draft, authentication: { ...draft.authentication, kind: event.target.value as RequestDraft['authentication']['kind'] } })}>
            <option>None</option><option>Bearer</option><option>Basic</option>
          </select></label>
          {draft.authentication.kind === 'Basic' && <label>Username<input value={draft.authentication.username} onChange={(event) => onChange({ ...draft, authentication: { ...draft.authentication, username: event.target.value } })} /></label>}
          {draft.authentication.kind !== 'None' && <label>{draft.authentication.kind === 'Bearer' ? 'Token' : 'Password'}<input type="password" value={draft.authentication.secret} onChange={(event) => onChange({ ...draft, authentication: { ...draft.authentication, secret: event.target.value } })} /></label>}
          <p>Credentials are excluded from request history.</p>
        </div>
      )}
    </section>
  );
}
