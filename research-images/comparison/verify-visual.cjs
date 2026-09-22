const { chromium }=require('C:/Users/Loadcomplete/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {pathToFileURL}=require('url');
const path=require('path');
(async()=>{
  const browser=await chromium.launch({headless:true,channel:'msedge'});
  const page=await browser.newPage({viewport:{width:1100,height:950}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(path.join(__dirname,'background-comparison-preview.html')).href);
  const frame=page.frameLocator('iframe');
  await frame.locator('#bg-ours-image').waitFor();
  const f=page.frames().find(f=>f!==page.mainFrame());
  await f.waitForFunction(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
  await frame.locator('#bg-outline').check();
  await frame.locator('#bg-gray').check();
  await frame.locator('#bg-room').selectOption('analysis_lab');
  await frame.locator('#bg-ours-title').filter({hasText:'검체 분석실'}).waitFor();
  const result={errors,images:await f.evaluate(()=>[...document.images].map(i=>({id:i.id,width:i.naturalWidth,height:i.naturalHeight}))),metrics:await frame.locator('#bg-metrics').textContent()};
  await frame.locator('#bg-room').selectOption('workshop');
  await frame.locator('#bg-gray').uncheck();
  await page.screenshot({path:path.join(__dirname,'visual-composition.png'),fullPage:true});
  await frame.locator('#bg-view').selectOption('perspective');
  await page.screenshot({path:path.join(__dirname,'visual-perspective.png'),fullPage:true});
  await frame.locator('#bg-view').selectOption('pixels');
  await page.screenshot({path:path.join(__dirname,'visual-pixels.png'),fullPage:true});
  result.widths=[];
  for(const width of [736,360,320]){
    await page.setViewportSize({width,height:950});
    for(const view of ['composition','pixels','perspective']){
      await frame.locator('#bg-view').selectOption(view);
      await frame.locator('#bg-'+view).waitFor();
      result.widths.push(await f.evaluate(({width,view})=>({width,view,client:document.documentElement.clientWidth,scroll:document.documentElement.scrollWidth}),{width,view}));
    }
  }
  process.stdout.write(JSON.stringify(result,null,2));
  await browser.close();
  if(errors.length||result.widths.some(x=>x.scroll>x.client+1))process.exitCode=1;
})();
