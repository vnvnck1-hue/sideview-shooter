local root=assert(app.params.root)
local pc=app.pixelColor
local timing={
 CeilingBell={anticipate={60,50,50,300},strike={16,16,24,170},hold={90,90,90,90},retract={45,45,70,160},close={60,60,80,110,180}},
 RingSpine={uncoil={200,20,20,80},lash={180,20,16,150},recoil={50,50,65,80,150},coil={70,50,50,90,180}},
 SeamAmbusher={emerge={100,60,50,260},snap={180,18,18,160},hold={100,100,100,100},release={40,40,60,90,160},withdraw={60,60,80,100,180}}
}
local nativeAtlas=Image(64,48,ColorMode.RGB);nativeAtlas:clear()
local fragmentMeta={cell=64,rows={}}
for row,id in ipairs({'CeilingBell','RingSpine','SeamAmbusher'})do
 local src=app.fs.joinPath(root,'Assets','Generated','CreatureProductionV1','processed',id)
 local out=app.fs.joinPath(root,'Assets','Generated','CreatureProductionV2',id)
 local runtime=app.fs.joinPath(root,'GodotPrototype','assets','character','Creatures',id)
 local normals=app.fs.joinPath(root,'GodotPrototype','assets','normals','character','Creatures',id)
 app.fs.makeAllDirectories(out);app.fs.makeAllDirectories(runtime);app.fs.makeAllDirectories(normals)
 local f=assert(io.open(app.fs.joinPath(src,'animation.json'),'r'));local m=json.decode(f:read('*a'));f:close()
 local sprite=app.open(app.fs.joinPath(src,id..'.aseprite'))
 m.schemaVersion=2;m.gameImported=true;m.timingStyle='held anticipation / ballistic snap / held impact';m.sourceVersion='CreatureProductionV1'
 m.rotationMode=id=='RingSpine'and'Runtime rigid rotation of canonical idle body; angle += actual travel / radius. No doubled baked roll.'or'anchored'
 for _,clip in ipairs(m.clips)do
  local t=timing[id][clip.name]
  if t then
   clip.durationsMs=t
   for j,ms in ipairs(t)do local index=clip.from+j;sprite.frames[index].duration=ms/1000;m.frames[index].durationMs=ms end
  end
 end
 sprite:saveAs(app.fs.joinPath(out,id..'.aseprite'))
 local function write(dir,name,obj)local h=assert(io.open(app.fs.joinPath(dir,name),'w'));h:write(json.encode(obj));h:close()end
 write(out,'animation.json',m);write(runtime,'animation.json',m)
 for i,fr in ipairs(m.frames)do
  local im=Image(sprite.spec);im:drawSprite(sprite,i)
  local nativeDir=app.fs.joinPath(out,'frames',fr.clip);app.fs.makeAllDirectories(nativeDir);im:saveAs(app.fs.joinPath(nativeDir,fr.key..'.png'))
  local gameDir=app.fs.joinPath(runtime,fr.clip);local normDir=app.fs.joinPath(normals,fr.clip);app.fs.makeAllDirectories(gameDir);app.fs.makeAllDirectories(normDir)
  local up=Image(im);up:resize(im.width*4,im.height*4);up:saveAs(app.fs.joinPath(gameDir,fr.key..'.png'))
  local nm=Image{fromFile=app.fs.joinPath(src,'runtime4x','normals',fr.clip,fr.key..'.png')};nm:saveAs(app.fs.joinPath(normDir,fr.key..'.png'))
 end
 -- Make coloured fragments from the actual approved body. Bright-bone candidates,
 -- spread across the source; no unrelated flesh atlas substituted for ivory plates.
 local body=Image(sprite.spec);body:drawSprite(sprite,1)
 local candidates={}
 for y=0,body.height-16,4 do for x=0,body.width-16,4 do
  local opaque,bone=0,0
  for yy=y,y+15 do for xx=x,x+15 do local c=body:getPixel(xx,yy);if pc.rgbaA(c)>0 then opaque=opaque+1;if pc.rgbaR(c)>160 and pc.rgbaG(c)>130 then bone=bone+1 end end end end
  if opaque>=80 then table.insert(candidates,{x=x,y=y,score=bone*2+opaque})end
 end end
 local selected={}
 for variant=0,3 do
  local best,score=nil,-1
  for _,c in ipairs(candidates)do
   local s=c.score;for _,p in ipairs(selected)do if math.abs(c.x-p.x)<12 and math.abs(c.y-p.y)<12 then s=s*.1 end end
   if s>score then best=c;score=s end
  end
  assert(best);table.insert(selected,best)
  for y=0,15 do for x=0,15 do nativeAtlas:drawPixel(variant*16+x,(row-1)*16+y,body:getPixel(best.x+x,best.y+y))end end
 end
 fragmentMeta.rows[id]={row=row-1,sourceFrame=m.frames[1].key,regions=selected}
 sprite:close();print('IMPORTED '..id..' with snap timing')
end
local fx=app.fs.joinPath(root,'GodotPrototype','assets','effects');app.fs.makeAllDirectories(fx)
nativeAtlas:resize(256,192);nativeAtlas:saveAs(app.fs.joinPath(fx,'creature_fragments.png'))
local f=assert(io.open(app.fs.joinPath(fx,'creature_fragments.json'),'w'));f:write(json.encode(fragmentMeta));f:close()
