local root=assert(app.params.root)
local id=assert(app.params.id)
local pc=app.pixelColor
local dir=app.fs.joinPath(root,'Assets','Generated','CreatureProductionV1','processed',id)
local function read(file)local f=assert(io.open(file,'r'));local s=f:read('*a');f:close();return json.decode(s)end
local m=read(app.fs.joinPath(dir,'animation.json'))
local sprite=assert(app.activeSprite)
assert(#sprite.frames==#m.frames and #sprite.tags==8,'frame/tag count mismatch')
assert(sprite.width==m.cell[1]and sprite.height==m.cell[2])
assert(#sprite.layers==3 and not sprite.layers[1].isVisible and sprite.layers[2].isVisible and sprite.layers[3].isVisible)
local colors={};local totalPixels=0
local atlas=Image{fromFile=app.fs.joinPath(dir,'atlas.png')}
local atlasData=read(app.fs.joinPath(dir,'atlas.json'))
assert(#atlasData.frames==#m.frames,'atlas frame count')
local clipSheets={};for _,clip in ipairs(m.clips)do clipSheets[clip.name]=Image{fromFile=app.fs.joinPath(dir,clip.sheet)}end
local results={id=id,frames=#m.frames,clips=#m.clips,checks={},issues={}}
for i,fr in ipairs(m.frames)do
 local im=Image(sprite.spec);im:drawSprite(sprite,i)
 local expected=Image{fromFile=app.fs.joinPath(dir,'frames',fr.clip,fr.key..'.png')}
 assert(expected.width==sprite.width and expected.height==sprite.height)
 assert(math.abs(sprite.frames[i].duration*1000-fr.durationMs)<1,'frame duration mismatch')
 local rect=atlasData.frames[i].frame;local nonempty=0
 for y=0,sprite.height-1 do for x=0,sprite.width-1 do
  local c=im:getPixel(x,y);local a=pc.rgbaA(c)
  assert(c==expected:getPixel(x,y),'Aseprite reopen/PNG mismatch '..fr.key)
  assert(c==clipSheets[fr.clip]:getPixel(fr.localFrame*sprite.width+x,y),'Clip sheet mismatch '..fr.key)
  assert(c==atlas:getPixel(rect.x+x,rect.y+y),'CLI atlas mismatch '..fr.key)
  assert(a==0 or a==255,'non-binary alpha '..fr.key)
  if x==0 or y==0 or x==sprite.width-1 or y==sprite.height-1 then assert(a==0,'canvas edge touched '..fr.key)end
  if a==255 then nonempty=nonempty+1;colors[c]=true end
 end end
 assert(nonempty>40,'Empty or nearly empty frame '..fr.key)
 assert(fr.clipped==0,'source bounds clipped '..fr.key)
 totalPixels=totalPixels+nonempty
end
local count=0;for _ in pairs(colors)do count=count+1 end;assert(count<=16,'palette exceeds 16 colours')
for j,clip in ipairs(m.clips)do
 local tag=sprite.tags[j];assert(tag.name==clip.name and tag.fromFrame.frameNumber==clip.from+1 and tag.toFrame.frameNumber==clip.to+1,'tag mismatch')
 assert(#clip.durationsMs==clip.to-clip.from+1)
 if clip.name=='death'then assert(not clip.loop,'death must not loop')end
end
results.paletteColors=count;results.opaquePixelSamples=totalPixels
results.checks={'Aseprite reopened successfully','Exact full RGBA equality: every individual PNG, every clip sheet, CLI atlas','All tags and frame durations match metadata','Common canvas and transparent one-pixel border in every frame','No projected source bounds clipped','Binary alpha and at most 16 opaque colours across all clips','Nonempty final death frame; death loop=false'}
results.status='passed'
local f=assert(io.open(app.fs.joinPath(dir,'verification.json'),'w'));f:write(json.encode(results));f:close()
print('VERIFIED '..id..': '..#m.frames..' frames / '..count..' colours / exact Aseprite-PNG-atlas match')
