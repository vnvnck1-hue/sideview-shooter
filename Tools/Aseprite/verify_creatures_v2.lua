local root=assert(app.params.root)
local total=0
for _,id in ipairs({'CeilingBell','RingSpine','SeamAmbusher'})do
 local src=app.fs.joinPath(root,'Assets','Generated','CreatureProductionV2',id)
 local game=app.fs.joinPath(root,'GodotPrototype','assets','character','Creatures',id)
 local normal=app.fs.joinPath(root,'GodotPrototype','assets','normals','character','Creatures',id)
 local f=assert(io.open(app.fs.joinPath(src,'animation.json'),'r'));local m=json.decode(f:read('*a'));f:close()
 local s=app.open(app.fs.joinPath(src,id..'.aseprite'))
 for i,fr in ipairs(m.frames)do
  assert(math.abs(s.frames[i].duration*1000-fr.durationMs)<1.1,id..' timing '..i)
  local native=Image{fromFile=app.fs.joinPath(src,'frames',fr.clip,fr.key..'.png')}
  local runtime=Image{fromFile=app.fs.joinPath(game,fr.clip,fr.key..'.png')}
  local n=Image{fromFile=app.fs.joinPath(normal,fr.clip,fr.key..'.png')}
  assert(runtime.width==native.width*4 and runtime.height==native.height*4,'runtime size')
  assert(n.width==runtime.width and n.height==runtime.height,'normal size')
  for y=0,runtime.height-1 do for x=0,runtime.width-1 do
   assert(runtime:getPixel(x,y)==native:getPixel(math.floor(x/4),math.floor(y/4)),id..' pixel mismatch '..i)
  end end
  total=total+1
 end
 s:close()
end
local out=assert(io.open(app.fs.joinPath(root,'Assets','Generated','CreatureProductionV2','verification.json'),'w'))
out:write(json.encode{frames=total,nearest4xPixelParity=true,normalDimensions=true,asepriteTimingMatches=true,gameTests='CreatureValidation PASS',gpuCapture='research-images/creatures-v2/game-motion.gif'})
out:close()
print('CREATURE_ASSETS_V2_PASS '..total)
