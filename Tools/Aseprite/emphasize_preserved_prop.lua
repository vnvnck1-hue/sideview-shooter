-- Non-destructive contrast variants of the source-mapped native sprite.
local sprite=assert(app.activeSprite)
local source=Image{fromFile=assert(app.params.source)}
local output=assert(app.params.output)
local strength=assert(app.params.strength)
local power,gain,cap
if strength=='medium'then power,gain,cap=1.22,.30,8
elseif strength=='strong'then power,gain,cap=1.48,.60,14
else error('Unsupported strength')end
local pc=app.pixelColor
local base=Image(sprite.spec);base:drawSprite(sprite,1)
local function luma(r,g,b)return .2126*r+.7152*g+.0722*b end
local function unpack(c)return pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)end
local function clamp(a,lo,hi)return math.max(lo,math.min(a,hi))end
local values,colors,seen={},{},{}
for y=0,base.height-1 do for x=0,base.width-1 do local c=base:getPixel(x,y)
 if pc.rgbaA(c)==255 then local r,g,b=unpack(c);values[#values+1]=luma(r,g,b)
  if not seen[c]then seen[c]=true;colors[#colors+1]=c end
 end
end end
table.sort(values);table.sort(colors)
local pivot=clamp(values[math.floor(#values*.60)],36,120)
local function curve(v)
 v=clamp(v,0,255)
 if v<pivot then return pivot*(v/pivot)^power end
 return 255-(255-pivot)*((255-v)/(255-pivot))^power
end
-- Preserve hue direction; compress chroma only as needed to stay in RGB gamut.
local function relight(r,g,b,target)
 local y=luma(r,g,b);local hi=math.max(r,g,b)-y;local lo=y-math.min(r,g,b);local k=1
 if hi>0 then k=math.min(k,(255-target)/hi)end
 if lo>0 then k=math.min(k,target/lo)end
 return math.floor(target+(r-y)*k+.5),math.floor(target+(g-y)*k+.5),math.floor(target+(b-y)*k+.5)
end
local palette={};local direct={}
for _,c in ipairs(colors)do local r,g,b=unpack(c);local rr,gg,bb=relight(r,g,b,curve(luma(r,g,b)))
 local q={r=rr,g=gg,b=bb,pixel=pc.rgba(rr,gg,bb,255)};palette[#palette+1]=q;direct[c]=q.pixel
end
local function nearest(r,g,b)
 local best,dist=palette[1],1e20
 for _,q in ipairs(palette)do local d=(q.r-r)^2+(q.g-g)^2+(q.b-b)^2;if d<dist then best=q;dist=d end end
 return best.pixel
end
local image=Image(sprite.spec);image:clear();local edgeChanged=0
for y=1,base.height-2 do for x=1,base.width-2 do local c=base:getPixel(x,y)
 if pc.rgbaA(c)==255 then
  local r,g,b=unpack(c);local lum=luma(r,g,b);local sum,n=0,0;local neighbors={}
  for dy=-1,1 do for dx=-1,1 do if dx~=0 or dy~=0 then
   local p=base:getPixel(x+dx,y+dy);if pc.rgbaA(p)==255 then local nr,ng,nb=unpack(p);local v=luma(nr,ng,nb);sum=sum+v;n=n+1;neighbors[#neighbors+1]=v end
  end end end
  local low,high=255,0
  for sy=(y-1)*2,math.min((y-1)*2+1,source.height-1)do for sx=(x-1)*2,math.min((x-1)*2+1,source.width-1)do
   local p=source:getPixel(sx,sy);if pc.rgbaA(p)>=128 then local sr,sg,sb=unpack(p);local v=luma(sr,sg,sb);low=math.min(low,v);high=math.max(high,v)end
  end end
  local restore=lum
  if n>=4 and high>=low then
   local mean=sum/n;local d=lum-mean;local support=0
   for _,v in ipairs(neighbors)do if (d>0 and v>mean+2)or(d<0 and v<mean-2)then support=support+1 end end
   if math.abs(d)>5 and support>=2 then
    -- Local restoration is bounded by actual source values, not a new outline halo.
    if d>0 then restore=lum+math.min(cap,gain*d,math.max(0,high-lum))
    else restore=lum-math.min(cap,-gain*d,math.max(0,lum-low))end
   end
  end
  local rr,gg,bb=relight(r,g,b,curve(restore));local result=nearest(rr,gg,bb)
  if result~=direct[c]then edgeChanged=edgeChanged+1 end
  image:drawPixel(x,y,result)
 end
end end
local layer=sprite:newLayer();layer.name='contrast_'..strength
sprite:newCel(layer,1,image,Point(0,0))
local pal=Palette(#palette+1);pal:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(palette)do pal:setColor(i,Color{r=c.r,g=c.g,b=c.b,a=255})end;sprite:setPalette(pal)
sprite:saveAs(output)
print(string.format('CONTRAST %s pivot=%.2f power=%.2f source-bounded edge changes=%d',strength,pivot,power,edgeChanged))
