const { execFileSync } = require('node:child_process');

const requireSession = () => {
  if (!process.env.BW_SESSION) {
    console.error('BW_SESSION is not set. Aborting without running bw.');
    process.exit(2);
  }
};

const bw = (...args) => execFileSync('bw', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();

const getLogin = (id) => {
  const item = JSON.parse(bw('get', 'item', id));
  if (!item.login) throw new Error('The vault item has no login fields');
  return { username: item.login.username ?? '', password: item.login.password ?? '', hasTotp: Boolean(item.login.totp) };
};

const findItems = (search) =>
  JSON.parse(bw('list', 'items', '--search', search))
    .filter((i) => i.login)
    .map((i) => ({ id: i.id, name: i.name, uris: (i.login.uris ?? []).map((u) => u.uri), totp: Boolean(i.login.totp) }));

module.exports = { requireSession, bw, getLogin, findItems };

const usage = () => {
  console.error('usage: node bw.cjs login\n       node bw.cjs search <query>\n       node bw.cjs run <vault-item-id> -- <command> [args...]');
  process.exit(2);
};

if (require.main === module) {
  requireSession();
  const [mode, arg, sep, ...cmd] = process.argv.slice(2);
  if (mode === 'login') {
    try {
      if (JSON.parse(bw('status')).status === 'unauthenticated') bw('login', '--apikey');
    } catch {
      console.error('bw login --apikey failed');
      process.exit(1);
    }
    try {
      bw('unlock', '--check');
    } catch {
      console.error('BW_SESSION is not valid for this vault.');
      process.exit(3);
    }
    bw('sync');
    console.log('status=unlocked');
  } else if (mode === 'search' && arg) {
    try {
      for (const i of findItems(arg)) console.log(`${i.id}\t${i.name}\t${i.uris.join(',')}\ttotp=${i.totp ? 'yes' : 'no'}`);
    } catch {
      console.error('bw list items failed');
      process.exit(1);
    }
  } else if (mode === 'run' && arg && sep === '--' && cmd.length) {
    let login;
    try {
      login = getLogin(arg);
    } catch {
      console.error('bw get item failed');
      process.exit(1);
    }
    const env = { ...process.env, ITEM_USERNAME: login.username, ITEM_PASSWORD: login.password };
    if (login.hasTotp) env.ITEM_TOTP = bw('get', 'totp', arg);
    for (const k of Object.keys(env)) if (k.startsWith('BW_')) delete env[k];
    const { status } = require('node:child_process').spawnSync(cmd[0], cmd.slice(1), { env, stdio: 'inherit' });
    process.exit(status ?? 1);
  } else usage();
}
