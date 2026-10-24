const crypto = require('node:crypto');

const BASE32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32Decode(input) {
  const out = [];
  let bits = 0;
  let value = 0;
  for (const ch of input.toUpperCase().replace(/[\s=-]/g, '')) {
    const idx = BASE32.indexOf(ch);
    if (idx < 0) throw new Error('invalid base32 character in TOTP secret');
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.push((value >>> bits) & 0xff);
      value &= (1 << bits) - 1;
    }
  }
  return Buffer.from(out);
}

function parseTotp(raw) {
  if (!raw) throw new Error('TOTP secret is empty');
  if (raw.startsWith('steam://')) throw new Error('Steam Guard TOTP is not supported');
  if (!raw.startsWith('otpauth://')) return { secret: raw.trim(), digits: 6, period: 30, algorithm: 'sha1' };
  const params = new URL(raw).searchParams;
  const secret = params.get('secret');
  if (!secret) throw new Error('otpauth URI has no secret');
  return {
    secret,
    digits: Number(params.get('digits') ?? 6),
    period: Number(params.get('period') ?? 30),
    algorithm: (params.get('algorithm') ?? 'SHA1').toLowerCase(),
  };
}

function generateTotp(raw, now = Date.now()) {
  const { secret, digits, period, algorithm } = parseTotp(raw);
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(now / 1000 / period)));
  const hmac = crypto.createHmac(algorithm, base32Decode(secret)).update(counter).digest();
  const offset = hmac[hmac.length - 1] & 0x0f;
  const code = (hmac.readUInt32BE(offset) & 0x7fffffff) % 10 ** digits;
  return String(code).padStart(digits, '0');
}

function secondsRemaining(raw, now = Date.now()) {
  const { period } = parseTotp(raw);
  return period - ((now / 1000) % period);
}

module.exports = { base32Decode, parseTotp, generateTotp, secondsRemaining };

if (require.main === module) {
  process.stdout.write(generateTotp(process.env.AAC_TOTP));
}
