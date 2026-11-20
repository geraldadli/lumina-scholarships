import { describe, test } from 'node:test';
import * as assert from 'node:assert/strict';
import { isHttpsUrlWithHost } from '../src/url';

describe('isHttpsUrlWithHost', () => {
  test('accepts https links with a real hostname', () => {
    for (const ok of [
      'https://example.org',
      'https://www.id.emb-japan.go.jp/sch.html',
      'https://example.org:8443/path?x=1#y',
      'https://[::1]/',
      'https://münchen.de/',
    ]) {
      assert.equal(isHttpsUrlWithHost(ok), true, `should pass: ${ok}`);
    }
  });

  test('rejects a bare https:// and links without a host', () => {
    for (const bad of [
      'https://',
      'https:///path',
      'https://?q=1',
      'https://#frag',
      'https://:8080',
      'https://@/x',
      'https://.com',
      'https://example.',
      'https://a..b',
      'https://exa mple.com',
    ]) {
      assert.equal(isHttpsUrlWithHost(bad), false, `should be rejected: ${bad}`);
    }
  });

  test('rejects other schemes, malformed values and non-strings', () => {
    for (const bad of ['http://example.org', 'ftp://example.org', 'example.org', 'https:/example.org', '', ' https://example.org']) {
      assert.equal(isHttpsUrlWithHost(bad), false, `should be rejected: ${JSON.stringify(bad)}`);
    }
    for (const bad of [undefined, null, 42, {}, []]) {
      assert.equal(isHttpsUrlWithHost(bad), false);
    }
  });
});
