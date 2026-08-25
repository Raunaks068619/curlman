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

  it('imports curl GET data-urlencode fields as query parameters', () => {
    const result = parseCurl(`curl --get \\
      'https://coach.co.za/ext/reco-extension/reco' \\
      --data-urlencode 'recommendation_slug=similar-products' \\
      --data-urlencode 'slug=tabby-bag-charm-198685064919' \\
      --data-urlencode 'currency_code=ZAR' \\
      -H 'Accept: application/json'`);

    expect(result.request.method).toBe('GET');
    expect(result.request.urlString).toBe('https://coach.co.za/ext/reco-extension/reco');
    expect(result.request.queryItems.filter((item) => item.isEnabled)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ name: 'recommendation_slug', value: 'similar-products' }),
        expect.objectContaining({ name: 'slug', value: 'tabby-bag-charm-198685064919' }),
        expect.objectContaining({ name: 'currency_code', value: 'ZAR' }),
      ]),
    );
    expect(result.request.headers).toEqual(expect.arrayContaining([expect.objectContaining({ name: 'Accept', value: 'application/json' })]));
    expect(result.request.bodyKind).toBe('None');
    expect(result.warnings).toEqual([]);
  });
});
