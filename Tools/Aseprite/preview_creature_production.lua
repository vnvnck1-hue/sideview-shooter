local root=assert(app.params.root);local id=assert(app.params.id)
local pc=app.pixelColor
local dir=app.fs.joinPath(root,'Assets','Generated','CreatureProductionV1','processed',id)
local f=assert(io.open(app.fs.joinPath(dir,'animation.json'),'r'));local m=json.decode(f:read('*a'));f:close()
local out=app.fs.joinPath(dir,'preview');app.fs.makeAllDirectories(out)
local frames={}
for _,fr in ipairs(m.frames)do frames[#frames+1]=Image{fromFile=app.fs.joinPath(dir,'frames',fr.clip,fr.key..'.png')}end
local function gif(name,indices)
 local zoom=3;local s=Sprite(m.cell[1]*zoom,m.cell[2]*zoom,ColorMode.RGB);s.layers[1].name='preview_on_checker'
 for i,index in ipairs(indices)do
  if i>1 then s:newEmptyFrame()end
  s.frames[i].duration=m.frames[index].durationMs/1000
  local im=Image(s.spec);local src=frames[index]
  for y=0,s.height-1 do for x=0,s.width-1 do
   local sx,sy=math.floor(x/zoom),math.floor(y/zoom);local c=src:getPixel(sx,sy)
   if pc.rgbaA(c)==0 then local dark=(math.floor(sx/8)+math.floor(sy/8))%2==0;c=dark and pc.rgba(29,34,42,255)or pc.rgba(35,40,49,255)end
   im:drawPixel(x,y,c)
  end end
  s:newCel(s.layers[1],i,im,Point(0,0))
 end
 s:saveAs(app.fs.joinPath(out,name..'.gif'));s:close()
end
local cycle={}
for _,clip in ipairs(m.clips)do
 local indices={};for i=clip.from+1,clip.to+1 do indices[#indices+1]=i end
 gif(clip.name,indices)
 if clip.name~='hurt'and clip.name~='death'then for _,i in ipairs(indices)do cycle[#cycle+1]=i end end
end
gif('attack_cycle',cycle)
print('EXPORTED previews for '..id)
