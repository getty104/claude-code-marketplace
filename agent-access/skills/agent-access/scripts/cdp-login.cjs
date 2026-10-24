const { chromium } = require('playwright');

const [url, userSel, passSel, submitSel] = process.argv.slice(2);
const { AAC_USERNAME, AAC_PASSWORD, CDP_ENDPOINT = 'http://localhost:9222' } = process.env;

if (!url || !userSel || !passSel || !submitSel) {
  console.error('usage: node cdp-login.cjs <login-url> <username-selector> <password-selector> <submit-selector>');
  process.exit(2);
}
if (!AAC_USERNAME || !AAC_PASSWORD) {
  console.error('AAC_USERNAME / AAC_PASSWORD are not set. Run via: aac run ... --env-all -- node cdp-login.cjs ...');
  process.exit(2);
}

(async () => {
  const browser = await chromium.connectOverCDP(CDP_ENDPOINT);
  const context = browser.contexts()[0] ?? await browser.newContext();
  const page = await context.newPage();
  await page.goto(url);
  await page.fill(userSel, AAC_USERNAME);
  await page.fill(passSel, AAC_PASSWORD);
  await Promise.all([page.waitForLoadState('load'), page.click(submitSel)]);
  await page.waitForLoadState('networkidle').catch(() => {});
  console.log(`after login: ${page.url()}`);
  await browser.close();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
