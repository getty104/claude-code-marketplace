const { chromium } = require('playwright');
const { generateTotp, secondsRemaining } = require('./totp.cjs');

const [url, userSel, passSel, submitSel, totpSel, totpSubmitSel] = process.argv.slice(2);
const { AAC_USERNAME, AAC_PASSWORD, AAC_TOTP, CDP_ENDPOINT = 'http://localhost:9222' } = process.env;

if (!url || !userSel || !passSel || !submitSel) {
  console.error('usage: node cdp-login.cjs <login-url> <username-selector> <password-selector> <submit-selector> [totp-selector] [totp-submit-selector]');
  process.exit(2);
}
if (!AAC_USERNAME || !AAC_PASSWORD) {
  console.error('AAC_USERNAME / AAC_PASSWORD are not set. Run via: aac run ... --env-all -- node cdp-login.cjs ...');
  process.exit(2);
}
if (totpSel && !AAC_TOTP) {
  console.error('totp-selector was given but AAC_TOTP is not set. The vault item has no TOTP secret.');
  process.exit(2);
}

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
  const browser = await chromium.connectOverCDP(CDP_ENDPOINT);
  const context = browser.contexts()[0] ?? await browser.newContext();
  const page = await context.newPage();
  try {
    await page.goto(url);
    await page.fill(userSel, AAC_USERNAME);
    await page.fill(passSel, AAC_PASSWORD);
    await submit(page, submitSel);
    if (totpSel) {
      await page.waitForSelector(totpSel);
      if (secondsRemaining(AAC_TOTP) < 3) await page.waitForTimeout(secondsRemaining(AAC_TOTP) * 1000 + 200);
      await page.fill(totpSel, generateTotp(AAC_TOTP));
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
