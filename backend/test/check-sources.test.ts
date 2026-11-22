import { describe, test } from 'node:test';
import * as assert from 'node:assert/strict';
import type { QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { checkOne } from '../src/check-sources';

const PAGE =
  '<html><body><h1>Scholarship</h1><p>Applications are open until the deadline stated on this official page.</p></body></html>';

const doc = (data: Record<string, unknown> = {}) =>
  ({ id: 'test-source', data: () => ({ scholarshipId: 'test-source', url: 'https://example.test/page', ...data }) }) as unknown as QueryDocumentSnapshot;

/** Server answers 200 right away, then never finishes sending the page until the request is aborted. */
function stalledBody(signal: AbortSignal): Response {
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      // AbortSignal.timeout() timers are unref'd, so without a ref'd handle the event loop can drain
      // while this stream is pending and the test runner cancels the test (seen on Node 22 / CI).
      const keepAlive = setInterval(() => {}, 1_000);
      signal.addEventListener(
        'abort',
        () => {
          clearInterval(keepAlive);
          controller.error(signal.reason);
        },
        { once: true },
      );
    },
  });
  return new Response(body, { status: 200, headers: { 'content-type': 'text/html' } });
}

const page = () => new Response(PAGE, { status: 200, headers: { 'content-type': 'text/html' } });

/** Fake `fetch` that replays one handler per call and records how often it was called. */
function scripted(...handlers: Array<(signal: AbortSignal) => Response>) {
  const calls: string[] = [];
  const fetchImpl = (async (input: string | URL | Request, init?: RequestInit) => {
    const handler = handlers[Math.min(calls.length, handlers.length - 1)]!;
    calls.push(String(input));
    return handler(init!.signal!);
  }) as typeof fetch;
  return { fetchImpl, calls };
}

describe('source check retries', () => {
  test('first download stalls mid-body, second attempt finishes -> source check succeeds', async () => {
    const { fetchImpl, calls } = scripted(stalledBody, page);
    const result = await checkOne(doc(), { fetchImpl, timeoutMs: 50, attempts: 2 });
    assert.equal(result.status, 'baseline');
    assert.equal(result.httpStatus, 200);
    assert.ok(result.hash, 'a content hash is stored');
    assert.equal(calls.length, 2, 'the page was requested twice');
  });

  test('every download stalls -> reports a timeout error after the last attempt', async () => {
    const { fetchImpl, calls } = scripted(stalledBody);
    const result = await checkOne(doc(), { fetchImpl, timeoutMs: 50, attempts: 2 });
    assert.equal(result.status, 'error');
    assert.match(result.error ?? '', /timeout|abort/i);
    assert.equal(calls.length, 2, 'no more than the configured attempts');
  });

  test('HTTP 5xx is retried', async () => {
    const { fetchImpl, calls } = scripted(() => new Response('', { status: 503 }), page);
    const result = await checkOne(doc(), { fetchImpl, timeoutMs: 50, attempts: 2 });
    assert.equal(result.status, 'baseline');
    assert.equal(calls.length, 2);
  });

  test('HTTP 4xx is reported without retrying', async () => {
    const { fetchImpl, calls } = scripted(() => new Response('', { status: 403 }), page);
    const result = await checkOne(doc(), { fetchImpl, timeoutMs: 50, attempts: 2 });
    assert.equal(result.status, 'error');
    assert.equal(result.httpStatus, 403);
    assert.equal(calls.length, 1);
  });

  test('unchanged page after a retry keeps the stored hash status', async () => {
    const first = await checkOne(doc(), { fetchImpl: scripted(page).fetchImpl, timeoutMs: 50 });
    const { fetchImpl } = scripted(stalledBody, page);
    const again = await checkOne(doc({ lastContentHash: first.hash }), { fetchImpl, timeoutMs: 50, attempts: 2 });
    assert.equal(again.status, 'unchanged');
  });
});
