const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
  const page = await browser.newPage({ viewport: { width: 2304, height: 941 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'scene_comparison.html').replaceAll('\\', '/'));
  await page.locator('img').evaluateAll(images => Promise.all(images.map(image => image.decode())));
  const crops = {
    'airlock-caretaker': { x: 1530, y: 315, width: 510, height: 350 },
    'security-controller': { x: 550, y: 315, width: 600, height: 350 },
    'hydroponics-keeper': { x: 995, y: 315, width: 850, height: 350 },
  };
  for (const id of Object.keys(crops)) {
    await page.locator('#' + id).evaluate(element => element.scrollIntoView({ block: 'start' }));
    await page.locator('#' + id).screenshot({ path: path.join(__dirname, id + '_scene_v4.png') });
    await page.screenshot({ path: path.join(__dirname, id + '_detail_v4.png'), clip: crops[id] });
  }
  await page.locator('#npc-lineup').evaluate(element => element.scrollIntoView({ block: 'start' }));
  await page.locator('#npc-lineup').screenshot({ path: path.join(__dirname, 'npc-lineup_scene_v4.png') });
  await page.screenshot({ path: path.join(__dirname, 'npc-lineup_detail_v4.png'), clip: { x: 570, y: 315, width: 1090, height: 350 } });
  for (const id of ['researcher-junior', 'researcher-senior']) {
    await page.locator('#' + id).evaluate(element => element.scrollIntoView({ block: 'start' }));
    await page.locator('#' + id).screenshot({ path: path.join(__dirname, id + '_scene_v1.png') });
  }
  await page.locator('#researcher-lineup').evaluate(element => element.scrollIntoView({ block: 'start' }));
  await page.locator('#researcher-lineup').screenshot({ path: path.join(__dirname, 'researcher-lineup_scene_v1.png') });
  await page.screenshot({ path: path.join(__dirname, 'researcher-lineup_detail_v1.png'), clip: { x: 700, y: 315, width: 960, height: 350 } });
  await page.locator('#player-redesign-comparison').evaluate(element => element.scrollIntoView({ block: 'start' }));
  await page.locator('#player-redesign-comparison').screenshot({ path: path.join(__dirname, '../PlayerConcepts/player_redesign_comparison_scene_v2.png') });
  await page.screenshot({ path: path.join(__dirname, '../PlayerConcepts/player_redesign_comparison_detail_v2.png'), clip: { x: 570, y: 315, width: 1460, height: 350 } });
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
