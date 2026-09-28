-- Preserve approved concept pixels, split into animation layers; no resampling/repaint.
local root=app.params["root"]
local out=root.."/GodotPrototype/assets/weapons/"
local ase=root.."/Assets/Generated/WeaponImplementation/Aseprite/"
local pc=app.pixelColor
local function inside(x,y,p)
 local c=false; local j=#p
 for i=1,#p do
  local a,b=p[i],p[j]
  if (a[2]>y)~=(b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then c=not c end
  j=i
 end
 return c
end
local function clean(img,seeds)
 local w,h=img.width,img.height
 local seen,queue={},{}; local n=1
 local function push(x,y)
  if x<0 or y<0 or x>=w or y>=h then return end
  local k=y*w+x
  if seen[k] then return end
  local p=img:getPixel(x,y)
  local r,g,b=pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p)
  if pc.rgbaA(p)<128 or (math.max(r,g,b)-math.min(r,g,b)<32 and math.min(r,g,b)>132) then
   seen[k]=true; queue[#queue+1]={x,y}
  end
 end
 for x=0,w-1 do push(x,0);push(x,h-1) end
 for y=0,h-1 do push(0,y);push(w-1,y) end
 for _,p in ipairs(seeds or {}) do push(p[1],p[2]) end
 while n<=#queue do
  local p=queue[n];n=n+1;img:drawPixel(p[1],p[2],0)
  push(p[1]-1,p[2]);push(p[1]+1,p[2]);push(p[1],p[2]-1);push(p[1],p[2]+1)
 end
 return img
end
local function source(path,rect)
 local s=app.open(path);local all=Image(s.width,s.height,ColorMode.RGB)
 all:drawSprite(s,1)
 local img=Image(rect[3],rect[4],ColorMode.RGB)
 img:drawImage(all,Point(-rect[1],-rect[2]));s:close()
 return clean(img)
end
local defs={
 {id="bulldog",file="P02_bulldog.png",rect={1084,188,420,374},foot={156,373},shoulder={87,166},muzzle={401,189},hip=258,
 gun={{87,181},{105,161},{145,135},{286,135},{305,111},{419,111},{419,250},{245,263},{149,250},{98,223}},
 legsplit=151},
 {id="coil",file="P03_coil_lance.png",rect={1142,200,371,366},foot={112,365},shoulder={51,166},muzzle={355,185},hip=254,
 gun={{43,172},{71,146},{96,139},{363,130},{370,260},{173,268},{102,235},{49,210}},
 legsplit=113}
}
for _,d in ipairs(defs) do
 local img=source(root.."/Deliverables/무기_컨셉_시안/"..d.file,d.rect)
 if d.id=="bulldog" then
  -- Floor rule is not part of the character. Open its border before flood fill.
  for y=369,img.height-1 do for x=0,img.width-1 do
   local p=img:getPixel(x,y); local r,g,b=pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p)
   if math.max(r,g,b)-math.min(r,g,b)<32 and r>85 then img:drawPixel(x,y,0) end
  end end
  clean(img,{{154,329}})
 end
 local s=Sprite(img.width,img.height,ColorMode.RGB)
 s.layers[1].name="body"
 local layers={body=s.layers[1],gun=s:newLayer(),leg_back=s:newLayer(),leg_front=s:newLayer()}
 layers.gun.name="gun";layers.leg_back.name="leg_back";layers.leg_front.name="leg_front"
 local ims={}
 for name,_ in pairs(layers) do ims[name]=Image(img.width,img.height,ColorMode.RGB) end
 for y=0,img.height-1 do for x=0,img.width-1 do
  local p=img:getPixel(x,y)
  local name="body"
  if inside(x,y,d.gun) then name="gun"
  elseif y>=d.hip then name=x<d.legsplit and "leg_back" or "leg_front" end
  ims[name]:drawPixel(x,y,p)
 end end
 -- Restore only the shirt area hidden by the held assembly. Every added pixel
 -- is covered in the neutral composite; aiming no longer opens a hole in torso.
 for y=160,d.hip-1 do for x=0,img.width-1 do
  local left=d.id=="bulldog" and 86 or 42
  local right=d.id=="bulldog" and 165 or 155
  if x>=left and x<=right and pc.rgbaA(ims.gun:getPixel(x,y))>0 then
   ims.body:drawPixel(x,y,pc.rgba(48,33,47,255))
  end
 end end
 for name,l in pairs(layers) do
  s:newCel(l,1,ims[name],Point(0,0))
  ims[name]:saveAs(out..d.id.."_"..name..".png")
 end
 img:saveAs(out..d.id.."_equipped.png")
 s:saveAs(ase..d.id..".aseprite")
 s:close()
 local f=io.open(out..d.id..".json","w")
 f:write(string.format('{"size":[%d,%d],"foot":[%d,%d],"shoulder":[%d,%d],"muzzle":[%d,%d],"hip":%d,"legsplit":%d,"world_height":264}',img.width,img.height,d.foot[1],d.foot[2],d.shoulder[1],d.shoulder[2],d.muzzle[1],d.muzzle[2],d.hip,d.legsplit))
 f:close()
end
-- Arc module: source extraction generated from approved hero; binary-alpha export.
local path=root.."/Assets/Generated/WeaponImplementation/Source/arc_weaver_turret.png"
local s=app.open(path);local im=Image(s.width,s.height,ColorMode.RGB);im:drawSprite(s,1)
for it in im:pixels() do local p=it(); if pc.rgbaA(p)<200 then it(0) else it(pc.rgba(pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p),255)) end end
s:close()
local final=Sprite(im.width,im.height,ColorMode.RGB);final:newCel(final.layers[1],1,im,Point(0,0));final.layers[1].name="Approved Arc Weaver"
final:saveAs(ase.."arc_weaver.aseprite");im:saveAs(out.."arc_weaver.png");final:close()
for _,d in ipairs({
 {id="bulldog_pellet",file="P02_bulldog.png",rect={600,734,140,67}},
 {id="coil_dart",file="P03_coil_lance.png",rect={244,750,486,98}},
 {id="arc_orb",file="B04_arc_weaver.png",rect={43,647,200,244}}
}) do
 local im=source(root.."/Deliverables/무기_컨셉_시안/"..d.file,d.rect)
 local sp=Sprite(im.width,im.height,ColorMode.RGB)
 sp:newCel(sp.layers[1],1,im,Point(0,0))
 sp.layers[1].name="Approved projectile"
 sp:saveAs(ase..d.id..".aseprite");im:saveAs(out..d.id..".png");sp:close()
end
print("WEAPON ASSETS EXPORTED")

