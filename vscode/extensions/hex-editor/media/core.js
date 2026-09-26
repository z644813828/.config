(function (root) {
  // Interpret bytes starting at the active cell; never read past the file boundary.
  function inspect(bytes, offset, littleEndian = true) {
    const values = {};
    const available = Math.max(0, bytes.length - offset);
    const view = new DataView(bytes.buffer, bytes.byteOffset + Math.min(offset, bytes.length), available);
    const format = value => Object.is(value, -0) ? '-0' : String(value);
    const read = (name, width, fn) => { values[name] = available >= width ? format(fn()) : 'End of File'; };
    read('binary', 1, () => bytes[offset].toString(2).padStart(8, '0'));
    read('octal', 1, () => bytes[offset].toString(8).padStart(3, '0'));
    for (const width of [1, 2, 3, 4, 8]) {
      const unsigned = () => {
        let value = 0n;
        for (let i = 0; i < width; i++) value = (value << 8n) | BigInt(bytes[offset + (littleEndian ? width - 1 - i : i)]);
        return value;
      };
      read(`uint${width * 8}`, width, unsigned);
      read(`int${width * 8}`, width, () => BigInt.asIntN(width * 8, unsigned()));
    }
    const leb = signed => {
      let value = 0n, shift = 0n;
      for (let i = 0; i < Math.min(available, 19); i++) {
        const byte = bytes[offset + i];
        value |= BigInt(byte & 127) << shift;
        shift += 7n;
        if (!(byte & 128)) {
          if (signed && (byte & 64)) value -= 1n << shift;
          const min = signed ? -(1n << 127n) : 0n;
          const max = (1n << (signed ? 127n : 128n)) - 1n;
          return value < min || value > max ? 'Overflow (128 bits)' : String(value);
        }
      }
      return available < 19 ? 'End of File' : 'Overflow (128 bits)';
    };
    values.ULEB128 = leb(false); values.SLEB128 = leb(true);
    read('float16', 2, () => {
      const bits = view.getUint16(0, littleEndian), sign = bits & 0x8000 ? -1 : 1;
      const exponent = (bits >> 10) & 31, fraction = bits & 1023;
      if (exponent === 31) return fraction ? NaN : sign * Infinity;
      return sign * (exponent ? (1 + fraction / 1024) * 2 ** (exponent - 15) : fraction * 2 ** -24);
    });
    read('bfloat16', 2, () => {
      const temp = new DataView(new ArrayBuffer(4));
      temp.setUint32(0, view.getUint16(0, littleEndian) * 65536);
      return temp.getFloat32(0);
    });
    read('float32', 4, () => view.getFloat32(0, littleEndian));
    read('float64', 8, () => view.getFloat64(0, littleEndian));
    read('GUID', 16, () => {
      const hex = (start, length, reverse = false) => {
        const chunk = Array.from(bytes.subarray(offset + start, offset + start + length));
        if (reverse) chunk.reverse();
        return chunk.map(byte => byte.toString(16).padStart(2, '0')).join('');
      };
      return [hex(0, 4, littleEndian), hex(4, 2, littleEndian), hex(6, 2, littleEndian), hex(8, 2), hex(10, 6)].join('-');
    });
    const printable = text => text.replace(/[\u0000-\u001f\u007f-\u009f]/g, '.');
    read('ASCII', 1, () => bytes[offset] < 128 ? printable(String.fromCharCode(bytes[offset])) : 'Invalid encoding');
    for (const [name, encoding] of [['UTF-8', 'utf-8'], ['UTF-16', littleEndian ? 'utf-16le' : 'utf-16be'], ['GB18030', 'gb18030'], ['BIG5', 'big5'], ['SHIFT-JIS', 'shift_jis']]) {
      values[name] = 'End of File';
      try {
        const decoder = new TextDecoder(encoding, { fatal: true, ignoreBOM: true });
        for (let i = 0; i < Math.min(available, 4); i++) {
          const text = decoder.decode(bytes.subarray(offset + i, offset + i + 1), { stream: true });
          if (text) { values[name] = printable(text); break; }
        }
      } catch { values[name] = 'Invalid encoding'; }
    }
    return values;
  }
  const api = {
    inspect,
    countMatches(bytes, pattern, onMatch) {
      if (!pattern.length) return 0;
      const prefix = new Uint32Array(pattern.length);
      for (let i = 1, j = 0; i < pattern.length; i++) {
        while (j && pattern[i] !== pattern[j]) j = prefix[j - 1];
        if (pattern[i] === pattern[j]) j++;
        prefix[i] = j;
      }
      let count = 0;
      for (let i = 0, j = 0; i < bytes.length; i++) {
        while (j && bytes[i] !== pattern[j]) j = prefix[j - 1];
        if (bytes[i] === pattern[j]) j++;
        if (j === pattern.length) { count++; if (onMatch) onMatch(i - pattern.length + 1); j = prefix[j - 1]; }
      }
      return count;
    },
    unsigned(bytes, offset, width, littleEndian = true) {
      if (![1, 2, 4, 8].includes(width)) throw new Error('Invalid integer width.');
      if (offset < 0 || offset + width > bytes.length) return null;
      let value = 0n;
      for (let i = 0; i < width; i++) value = (value << 8n) | BigInt(bytes[offset + (littleEndian ? width - 1 - i : i)]);
      return value;
    },
    formatUnsigned(bytes, offset, width, radix = 16, littleEndian = true) {
      const value = api.unsigned(bytes, offset, width, littleEndian);
      if (value === null) return '—';
      return radix === 16 ? value.toString(16).toUpperCase().padStart(width * 2, '0') : value.toString(10);
    },
    encodeUnsigned(input, width, radix = 16, littleEndian = true) {
      if (![1, 2, 4, 8].includes(width)) throw new Error('Invalid integer width.');
      const text = input.trim();
      if (!(radix === 16 ? /^(?:0x)?[0-9a-f]+$/i : /^[0-9]+$/).test(text)) throw new Error('Enter an unsigned ' + (radix === 16 ? 'hexadecimal' : 'decimal') + ' integer.');
      let value = BigInt(radix === 16 ? '0x' + text.replace(/^0x/i, '') : text);
      if (value >= (1n << BigInt(width * 8))) throw new Error(`Value exceeds uint${width * 8}_t.`);
      const result = new Uint8Array(width);
      for (let i = 0; i < width; i++) { result[littleEndian ? i : width - 1 - i] = Number(value & 255n); value >>= 8n; }
      return result;
    },
    address(input, length, radix) {
      const value = input.trim();
      if (radix === 16 ? !/^(?:0x)?[0-9a-f]+$/i.test(value) : radix === 10 ? !/^[0-9]+$/.test(value) : !/^(?:0x[0-9a-f]+|[0-9]+)$/i.test(value)) throw new Error(radix === 16 ? 'Enter a hexadecimal address (0–9, A–F).' : radix === 10 ? 'Enter a decimal address (0–9).' : 'Use a decimal address or 0x-prefixed hexadecimal address.');
      const offset = radix === 16 ? Number.parseInt(value, 16) : Number(value);
      if (!Number.isSafeInteger(offset) || offset < 0 || offset >= length) throw new Error('Address is outside the file.');
      return offset;
    },
    pattern(input, mode) {
      if (mode === 'text') return new TextEncoder().encode(input);
      const hex = input.replace(/\s/g, '');
      if (!hex || !/^(?:[0-9a-f]{2})+$/i.test(hex)) throw new Error('Enter complete hexadecimal bytes, for example DE AD BE EF.');
      return Uint8Array.from(hex.match(/../g), value => parseInt(value, 16));
    },
    find(bytes, pattern, start, direction = 1) {
      if (!pattern.length || pattern.length > bytes.length) return -1;
      const count = bytes.length - pattern.length + 1;
      start = ((start % count) + count) % count;
      for (let step = 0; step < count; step++) {
        const offset = (start + direction * step + count) % count;
        let index = 0;
        while (index < pattern.length && bytes[offset + index] === pattern[index]) index++;
        if (index === pattern.length) return offset;
      }
      return -1;
    }
  };
  if (typeof module !== 'undefined') module.exports = api;
  else root.HexCore = api;
})(globalThis);
