const { test } = require('node:test');
const assert = require('node:assert/strict');
const { inspect } = require('../media/core');
const read = (bytes, le = true, offset = 0) => inspect(Uint8Array.from(bytes), offset, le);
test('integer endian, sign, 24-bit widths and exact 64-bit precision', () => {
  const v = read([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
  assert.equal(v.uint64, '18446744073709551615'); assert.equal(v.int64, '-1');
  assert.equal(v.uint24, '16777215'); assert.equal(v.int24, '-1');
  assert.equal(v.binary, '11111111'); assert.equal(v.octal, '377');
  assert.equal(read([1, 2, 3]).uint24, '197121');
  assert.equal(read([1, 2, 3], false).uint24, '66051');
  assert.equal(read([0, 0, 128]).int24, '-8388608');
  assert.equal(read([9, 1, 2], false, 1).uint16, '258');
});
test('float representations handle subnormal, negative zero, infinity and NaN', () => {
  assert.equal(read([0, 0x3c]).float16, '1');
  assert.equal(read([0x3c, 0], false).float16, '1');
  assert.equal(read([1, 0]).float16, String(2 ** -24));
  assert.equal(read([0, 0x80]).float16, '-0');
  assert.equal(read([0, 0x7c]).float16, 'Infinity');
  assert.equal(read([1, 0x7c]).float16, 'NaN');
  assert.equal(read([0x80, 0x3f]).bfloat16, '1');
  assert.equal(read([0, 0, 0x80, 0x3f]).float32, '1');
  assert.equal(read([0, 0, 0, 0, 0, 0, 0xf0, 0x3f]).float64, '1');
});
test('LEB128 decoding, incomplete sequences and overflow', () => {
  assert.equal(read([0xe5, 0x8e, 0x26]).ULEB128, '624485');
  assert.equal(read([0x9b, 0xf1, 0x59]).SLEB128, '-624485');
  assert.equal(read([0x7f]).SLEB128, '-1');
  assert.equal(read([0x80]).ULEB128, 'End of File');
  assert.equal(read(Array(19).fill(0xff)).ULEB128, 'Overflow (128 bits)');
  assert.equal(read([...Array(18).fill(0xff), 3]).ULEB128, String((1n << 128n) - 1n));
});
test('GUID field ordering and file boundaries', () => {
  const bytes = Array.from({ length: 16 }, (_, i) => i);
  assert.equal(read(bytes).GUID, '03020100-0504-0706-0809-0a0b0c0d0e0f');
  assert.equal(read(bytes, false).GUID, '00010203-0405-0607-0809-0a0b0c0d0e0f');
  assert.equal(read([1]).uint16, 'End of File');
  assert.ok(Object.values(read([])).every(value => value === 'End of File'));
});
test('first decoded character, invalid input, partial characters and control bytes', () => {
  assert.equal(read([65, 66]).ASCII, 'A');
  assert.equal(read([0]).ASCII, '.');
  assert.equal(read([255])['UTF-8'], 'Invalid encoding');
  assert.equal(read([0xe2, 0x82])['UTF-8'], 'End of File');
  assert.equal(read([0xf0, 0x9f, 0x98, 0x80])['UTF-8'], '😀');
  assert.equal(read([0x3d, 0xd8, 0, 0xde])['UTF-16'], '😀');
  assert.equal(read([0, 65], false)['UTF-16'], 'A');
  assert.equal(read([0x82, 0xa0])['SHIFT-JIS'], 'あ');
  assert.equal(read([0xa4, 0xa4]).BIG5, '中');
  assert.equal(read([0xd6, 0xd0]).GB18030, '中');
});
