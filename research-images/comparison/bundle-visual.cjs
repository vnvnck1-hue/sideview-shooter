// Mechanical image encoding/data embedding only. No game assets are modified.
const fs = require('fs');
const path = require('path');
const sharp = require('C:/Users/Loadcomplete/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../..');
const dir = 'C:/Users/Loadcomplete/.codex/visualizations/2026/09/22/01a0c792-3e77-7f32-b584-08f348b2cb36';
const asset = p => path.join(root, 'GodotPrototype/assets', p);
async function uri(file, crop) {
  let img = sharp(file);
  if (crop) img = img.extract(crop);
  const buffer = crop ? await img.png().toBuffer() : await img.resize(1120,450,{kernel:'nearest'}).webp({quality:84}).toBuffer();
  return `data:image/${crop?'png':'webp'};base64,${buffer.toString('base64')}`;
}
(async () => {
  const captures = JSON.parse(fs.readFileSync(path.join(__dirname,'capture_metadata.json'),'utf8'));
  const measurements = JSON.parse(fs.readFileSync(path.join(__dirname,'measurements.json'),'utf8'));
  const data = {rooms:{},pixels:{},ms:'data:image/jpeg;base64,'+fs.readFileSync(path.join(root,'research-images/metal-slugx-industrial.jpg')).toString('base64')};
  for (const c of captures) data.rooms[c.room] = {image:await uri(path.join(__dirname,c.room+'_world.png')),columns:c.columns_screen,feet:c.player_feet,area:measurements.rooms.find(r=>r.room===c.room).room_silhouette_area_percent};
  data.pixels.wall=await uri(asset('tiles/workshop_modular/workshop_modular_background_sheet_3x2.png'),{left:128,top:64,width:128,height:128});
  data.pixels.locker=await uri(asset('props/workshop_locker_game_scale.png'),{left:48,top:48,width:128,height:128});
  data.pixels.bench=await uri(asset('props/research_analysis/research_analysis_analysis_bench.png'),{left:0,top:32,width:128,height:128});
  const template=fs.readFileSync(path.join(dir,'background-comparison.template.html'),'utf8');
  const output=template.replace('@@DATA@@',JSON.stringify(data));
  if(Buffer.byteLength(output)>1000000)throw new Error('Inline visualization exceeds size limit');
  fs.writeFileSync(path.join(dir,'background-comparison.html'),output);
  process.stdout.write(JSON.stringify({file:path.join(dir,'background-comparison.html'),bytes:Buffer.byteLength(output)}));
})();
