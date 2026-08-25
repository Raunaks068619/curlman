import { describe, expect, it } from 'vitest';
import { exportCurl, parseCurl } from './curl';

describe('cURL import and export', () => {
  it('parses and formats the multiline POST workflow used by Curlman', () => {
    const result = parseCurl(`curl --request POST \\
      --url 'https://example.com/workflows/execute?id=42' \\
      --header 'content-type: application/json' \\
      --data-raw '{"caller":"manual-test","enabled":true}'`);

    expect(result.request.method).toBe('POST');
    expect(result.request.urlString).toBe('https://example.com/workflows/execute');
    expect(result.request.queryItems[0]).toMatchObject({ name: 'id', value: '42' });
    expect(result.request.body).toBe('{\n  "caller": "manual-test",\n  "enabled": true\n}');
  });

  it('exports the edited request as a runnable shell-safe command', () => {
    const request = parseCurl(`curl 'https://example.com/items' -H 'X-Name: Raunak' -d "{\\"name\\":\\"Sam's Mac\\"}"`).request;
    const exported = exportCurl(request);

    expect(exported).toContain('curl --request POST');
    expect(exported).toContain("--header 'X-Name: Raunak'");
    expect(exported).toContain("Sam'\\''s Mac");
  });
});
