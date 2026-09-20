// Static artifact checks only. No browser, network, or DOM execution.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),lab=path.join(root,'Assets/Generated/PropStyleLab');
const html=fs.readFileSync(path.join(lab,'review.html'),'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script,{filename:'review.html'});
const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
assert.equal(new Set(ids).size,ids.length,'duplicate IDs');
for(const m of script.matchAll(/getElementById\('([^']+)'\)/g))assert(ids.includes(m[1]),'missing control '+m[1]);
for(const m of html.matchAll(/(?:src|href)="([^"]+)"/g))assert(fs.existsSync(path.resolve(lab,m[1])),'missing local link '+m[1]);
for(const name of ['analysis_bench','cold_storage','specimen_chamber'])for(const stage of ['baseline','r1','r2','r3'])assert(fs.existsSync(path.join(lab,stage,name+'.png')));
for(const name of ['workshop_workbench_game_scale','workshop_locker_game_scale','hydroponics_growth_tank_full'])assert(fs.existsSync(path.join(lab,'references',name+'.png')));
for(const theme of ['workshop','research_analysis'])for(const scale of [1,2,3,6])assert(fs.existsSync(path.join(lab,'review-r3',`assembly-${theme}-x${scale}.png`)));
console.log('PASS: HTML JavaScript syntax, control IDs, local links, 12 stage images, 3 references, 8 scene variants. Browser layout/interaction not tested.');
