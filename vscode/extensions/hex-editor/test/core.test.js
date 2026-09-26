const { test } = require('node:test');
const assert = require('node:assert/strict');
const { address, pattern, find } = require('../media/core');
test('addresses validate radix, boundaries and unsafe integers', () => {
  assert.equal(address('0xAF', 256), 175);
  assert.equal(address('010', 256), 10);
  for (const value of ['-1', '0x', '2.5', '256', '9007199254740992', '12tail']) assert.throws(() => address(value, 256));
  assert.throws(() => address('0', 0));
});
test('patterns preserve zero bytes and UTF-8 text', () => {
  assert.deepEqual([...pattern('00 fF\n0a', 'hex')], [0, 255, 10]);
  assert.deepEqual(pattern('Привет', 'text'), new TextEncoder().encode('Привет'));
  for (const value of ['', 'a', 'zz', '0xFF']) assert.throws(() => pattern(value, 'hex'));
});
test('search wraps in both directions, includes overlapping and final matches', () => {
  const data = Uint8Array.of(1, 1, 1, 2, 0);
  assert.equal(find(data, Uint8Array.of(1, 1), 1), 1);
  assert.equal(find(data, Uint8Array.of(1, 1), 2), 0);
  assert.equal(find(data, Uint8Array.of(1, 1), -1, -1), 1);
  assert.equal(find(data, Uint8Array.of(2, 0), 0), 3);
  assert.equal(find(data, Uint8Array.of(9), 0), -1);
  assert.equal(find(data, new Uint8Array(), 0), -1);
  assert.equal(find(new Uint8Array(), Uint8Array.of(0), 0), -1);
});

test('match totals include overlapping occurrences and exact file boundaries', () => {
  const { countMatches } = require('../media/core');
  assert.equal(countMatches(Uint8Array.of(0, 1, 9, 0, 1), Uint8Array.of(0, 1)), 2);
  assert.equal(countMatches(Uint8Array.of(0, 0, 0), Uint8Array.of(0, 0)), 2);
  assert.equal(countMatches(Uint8Array.of(0), Uint8Array.of(0, 1)), 0);
  assert.equal(countMatches(Uint8Array.of(0), new Uint8Array()), 0);
});
