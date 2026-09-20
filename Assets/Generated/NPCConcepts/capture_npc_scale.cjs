const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
  const page = await browser.newPage({ viewport: { width: 2304, height: 941 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'npc_scale_review.html').replaceAll('\\', '/'));
  await page.waitForFunction(() => window.ready === true);
  for (const id of ['cast', 'caretaker', 'security', 'keeper', 'junior', 'senior']) {
    await page.locator('#' + id).evaluate(element => element.scrollIntoView({ block: 'start' }));
    await page.locator('#' + id).screenshot({ path: path.join(__dirname, id + '_player_scale_scene.png') });
  }
  await page.locator('#cast').evaluate(element => element.scrollIntoView({ block: 'start' }));
  await page.screenshot({ path: path.join(__dirname, 'cast_player_scale_detail.png'), clip: { x: 180, y: 315, width: 1740, height: 350 } });
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
