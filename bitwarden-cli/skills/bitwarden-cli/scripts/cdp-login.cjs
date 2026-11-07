const { chromium } = require('playwright');
const { requireSession, bw, getLogin } = require('./bw.cjs');

const [id, url, userSel, passSel, submitSel, totpSel, totpSubmitSel] = process.argv.slice(2);
const CDP_ENDPOINT = process.env.CDP_ENDPOINT ?? 'http://localhost:9222';

if (!id || !url || !userSel || !passSel || !submitSel) {
  console.error('usage: node cdp-login.cjs <vault-item-id> <login-url> <username-selector> <password-selector> <submit-selector> [totp-selector] [totp-submit-selector]');
  process.exit(2);
}
requireSession();

const submit = async (page, selector, fallbackSel) => {
  const action = selector ? page.click(selector) : page.press(fallbackSel, 'Enter');
  await Promise.all([page.waitForLoadState('load'), action]);
  await page.waitForLoadState('networkidle').catch(() => {});
};

const clearPassword = async (page) => {
  const field = page.locator(passSel);
  if (await field.count().catch(() => 0)) await field.first().fill('').catch(() => {});
};

(async () => {
  const login = getLogin(id);
  if (totpSel && !login.hasTotp) {
    console.error('totp-selector was given but the vault item has no TOTP secret.');
    process.exit(2);
  }
  const browser = await chromium.connectOverCDP(CDP_ENDPOINT);
  const context = browser.contexts()[0] ?? await browser.newContext();
  const page = await context.newPage();
  try {
    await page.goto(url);
    await page.fill(userSel, login.username);
    await page.fill(passSel, login.password);
    await submit(page, submitSel);
    if (totpSel) {
      await page.waitForSelector(totpSel);
      // shortcut: assumes a 30s TOTP period, switch to the item's otpauth period if a site uses another
      const remaining = 30 - (Math.floor(Date.now() / 1000) % 30);
      if (remaining < 3) await page.waitForTimeout(remaining * 1000 + 200);
      await page.fill(totpSel, bw('get', 'totp', id));
      await submit(page, totpSubmitSel, totpSel);
    }
    const { origin, pathname } = new URL(page.url());
    console.log(`after login: ${origin}${pathname}`);
  } finally {
    await clearPassword(page);
    await browser.close();
  }
})().catch((e) => {
  console.error(e.message.split('\n')[0]);
  process.exit(1);
});
