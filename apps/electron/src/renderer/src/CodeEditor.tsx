import { json } from '@codemirror/lang-json';
import CodeMirror from '@uiw/react-codemirror';

interface CodeEditorProps {
  value: string;
  onChange?: (value: string) => void;
  readOnly?: boolean;
  language?: 'json' | 'raw';
  label: string;
}

export function CodeEditor({ value, onChange, readOnly = false, language = 'json', label }: CodeEditorProps) {
  return (
    <div className="code-editor" aria-label={label}>
      <CodeMirror
        value={value}
        height="100%"
        minHeight="280px"
        extensions={language === 'json' ? [json()] : []}
        onChange={onChange}
        readOnly={readOnly}
        editable={!readOnly}
        basicSetup={{
          autocompletion: false,
          bracketMatching: true,
          closeBrackets: !readOnly,
          foldGutter: true,
          highlightActiveLine: !readOnly,
          highlightActiveLineGutter: !readOnly,
          lineNumbers: true,
          searchKeymap: true,
        }}
      />
    </div>
  );
}
