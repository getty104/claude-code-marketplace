const test = require('node:test');
const assert = require('node:assert');
const { generateTotp, parseTotp, secondsRemaining } = require('./totp.cjs');

const b32 = (s) => {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const byte of Buffer.from(s)) bits += byte.toString(2).padStart(8, '0');
  return bits.match(/.{1,5}/g).map((c) => alphabet[parseInt(c.padEnd(5, '0'), 2)]).join('');
};

const SHA1 = b32('12345678901234567890');
const SHA256 = b32('12345678901234567890123456789012');
const SHA512 = b32('1234567890'.repeat(6) + '1234');

test('RFC 6238 test vectors', () => {
  const cases = [
    [SHA1, 'SHA1', 59, '94287082'],
    [SHA1, 'SHA1', 1111111109, '07081804'],
    [SHA1, 'SHA1', 1111111111, '14050471'],
    [SHA1, 'SHA1', 1234567890, '89005924'],
    [SHA1, 'SHA1', 2000000000, '69279037'],
    [SHA256, 'SHA256', 59, '46119246'],
    [SHA256, 'SHA256', 1111111109, '68084774'],
    [SHA512, 'SHA512', 59, '90693936'],
    [SHA512, 'SHA512', 1111111109, '25091201'],
  ];
  for (const [secret, algorithm, t, expected] of cases) {
    const uri = `otpauth://totp/test?secret=${secret}&digits=8&algorithm=${algorithm}`;
    assert.strictEqual(generateTotp(uri, t * 1000), expected, `${algorithm} T=${t}`);
  }
});

test('bare base32 secret defaults to 6 digits / 30s / SHA1', () => {
  assert.strictEqual(generateTotp(SHA1, 59 * 1000), '287082');
  assert.strictEqual(generateTotp(SHA1.toLowerCase().replace(/(.{4})/g, '$1 '), 59 * 1000), '287082');
});

test('rejects unsupported or empty secrets', () => {
  assert.throws(() => parseTotp(''), /empty/);
  assert.throws(() => parseTotp('steam://ABC'), /Steam/);
  assert.throws(() => generateTotp('not-base32!'), /base32/);
});

test('secondsRemaining', () => {
  assert.strictEqual(secondsRemaining(SHA1, 59 * 1000), 1);
  assert.strictEqual(secondsRemaining(`otpauth://totp/x?secret=${SHA1}&period=60`, 59 * 1000), 1);
});
