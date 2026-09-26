const { test } = require('node:test');
const assert = require('node:assert/strict');
const { unsigned, formatUnsigned, encodeUnsigned } = require('../media/core');
test('grouped values use exact unsigned arithmetic and endian-aware encoding', () => {
  for (const width of [1, 2, 4, 8]) for (const littleEndian of [false, true]) for (const radix of [10, 16]) {
    for (const value of [0n, 1n, (1n << BigInt(width * 8)) - 1n]) {
      const bytes = encodeUnsigned(value.toString(radix), width, radix, littleEndian);
      assert.equal(unsigned(bytes, 0, width, littleEndian), value);
      assert.equal(formatUnsigned(bytes, 0, width, radix, littleEndian), radix === 16 ? value.toString(16).toUpperCase().padStart(width * 2, '0') : value.toString());
    }
  }
  assert.deepEqual([...encodeUnsigned('12345678', 4, 16, true)], [0x78, 0x56, 0x34, 0x12]);
  assert.deepEqual([...encodeUnsigned('12345678', 4, 16, false)], [0x12, 0x34, 0x56, 0x78]);
  assert.equal(formatUnsigned(Uint8Array.of(1), 0, 2), '—');
  assert.equal(formatUnsigned(Uint8Array.of(0, 1, 2), 1, 2, 10, false), '258');
});
test('invalid and overflowing values are rejected without truncation', () => {
  for (const text of ['-1', '256', '1.5', '1e2', '', '0xFF']) assert.throws(() => encodeUnsigned(text, 1, 10));
  for (const text of ['100', '-1', 'GG', '0x']) assert.throws(() => encodeUnsigned(text, 1, 16));
  assert.throws(() => encodeUnsigned('18446744073709551616', 8, 10));
});
