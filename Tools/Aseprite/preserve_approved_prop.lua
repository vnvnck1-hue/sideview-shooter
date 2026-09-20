-- Source-driven pixel conversion. No invented silhouettes or generic replacement palette.
local input=assert(app.params.input);local out=assert(app.params.output)
local step=tonumber(app.params.step or '2');local budget=tonumber(app.params.colors or '96')
local src=Image{fromFile=input};assert(src.colorMode==ColorMode.RGB,'RGBA input required')
local pc=app.pixelColor
local w,h=math.ceil(src.width/step)+2,math.ceil(src.height/step)+2
local pixels={};local hist={};local points={}
local function rgb(c)return pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)end
for y=0,h-3 do for x=0,w-3 do
 local count,area,sr,sg,sb=0,0,0,0,0
 for yy=y*step,math.min((y+1)*step-1,src.height-1)do for xx=x*step,math.min((x+1)*step-1,src.width-1)do
  local c=src:getPixel(xx,yy);area=area+1
  if pc.rgbaA(c)>=128 then local r,g,b=rgb(c);count=count+1;sr=sr+r;sg=sg+g;sb=sb+b end
 end end
 if count>0 and count*2>=area then
  local r,g,b=math.floor(sr/count+.5),math.floor(sg/count+.5),math.floor(sb/count+.5)
  if app.params.representative=='source' then
   local best=1e20;local rr,gg,bb=r,g,b
   for yy=y*step,math.min((y+1)*step-1,src.height-1)do for xx=x*step,math.min((x+1)*step-1,src.width-1)do
    local c=src:getPixel(xx,yy)
    if pc.rgbaA(c)>=128 then local cr,cg,cb=rgb(c);local d=(cr-r)^2+(cg-g)^2+(cb-b)^2
     if d<best then best=d;rr=cr;gg=cg;bb=cb end
    end
   end end
   r,g,b=rr,gg,bb
  end
  local key=math.floor(r/4)*4096+math.floor(g/4)*64+math.floor(b/4)
  local q=hist[key]
  if not q then q={r=0,g=0,b=0,n=0,key=key};hist[key]=q;points[#points+1]=q end
  q.r=q.r+r;q.g=q.g+g;q.b=q.b+b;q.n=q.n+1
  pixels[#pixels+1]={x=x+1,y=y+1,r=r,g=g,b=b}
 end
end end
for _,q in ipairs(points)do q.r=q.r/q.n;q.g=q.g/q.n;q.b=q.b/q.n end
-- Weighted median cut with RGB-range priorities, followed by deterministic Lloyd refinement.
local function describe(list)
 local lo={r=255,g=255,b=255};local hi={r=0,g=0,b=0};local n=0
 for _,q in ipairs(list)do n=n+q.n;for _,k in ipairs({'r','g','b'})do lo[k]=math.min(lo[k],q[k]);hi[k]=math.max(hi[k],q[k])end end
 local axis='r';for _,k in ipairs({'g','b'})do if hi[k]-lo[k]>hi[axis]-lo[axis]then axis=k end end
 return {list=list,axis=axis,score=(hi[axis]-lo[axis])*math.sqrt(n),n=n}
end
local boxes={describe(points)}
while #boxes<budget do
 local best=nil
 for i,box in ipairs(boxes)do if #box.list>1 and(not best or box.score>boxes[best].score)then best=i end end
 if not best then break end
 local box=table.remove(boxes,best);local axis=box.axis
 table.sort(box.list,function(a,b)if a[axis]==b[axis]then return a.key<b.key else return a[axis]<b[axis]end end)
 local a,b={},{};local weight=0
 for i,q in ipairs(box.list)do if weight<box.n/2 and i<#box.list then a[#a+1]=q else b[#b+1]=q end;weight=weight+q.n end
 boxes[#boxes+1]=describe(a);boxes[#boxes+1]=describe(b)
end
local palette={}
for _,box in ipairs(boxes)do
 local r,g,b=0,0,0;for _,q in ipairs(box.list)do r=r+q.r*q.n;g=g+q.g*q.n;b=b+q.b*q.n end
 palette[#palette+1]={r=r/box.n,g=g/box.n,b=b/box.n}
end
local function nearest(q,limit)
 local best,dist=1,1e20
 for i=1,(limit or #palette)do local c=palette[i];local d=(q.r-c.r)^2+(q.g-c.g)^2+(q.b-c.b)^2
  if d<dist then best=i;dist=d end
 end
 return best,dist
end
for iteration=1,8 do
 local sums={};for i=1,#palette do sums[i]={r=0,g=0,b=0,n=0}end
 for _,q in ipairs(points)do local k=nearest(q);local a=sums[k];a.r=a.r+q.r*q.n;a.g=a.g+q.g*q.n;a.b=a.b+q.b*q.n;a.n=a.n+q.n end
 for i,a in ipairs(sums)do if a.n>0 then palette[i]={r=a.r/a.n,g=a.g/a.n,b=a.b/a.n}end end
end
local basePaletteSize=#palette
-- Preserve rare source colours in an inspected functional object, not a generic invented swatch.
if app.params.protect=='wash_soap' then
 local groups={}
 for _,q in ipairs(pixels)do
  if q.x>=55 and q.x<=74 and q.y>=41 and q.y<=54 and q.g-q.r>5 then
   local key=math.floor(q.r/16)*256+math.floor(q.g/16)*16+math.floor(q.b/16)
   if not groups[key]then groups[key]={r=0,g=0,b=0,n=0}end
   local a=groups[key];a.r=a.r+q.r;a.g=a.g+q.g;a.b=a.b+q.b;a.n=a.n+1
  end
 end
 local keys={};for k in pairs(groups)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do local a=groups[k];palette[#palette+1]={r=a.r/a.n,g=a.g/a.n,b=a.b/a.n}end
end
local pal=Palette(#palette+1);pal:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(palette)do c.r=math.floor(c.r+.5);c.g=math.floor(c.g+.5);c.b=math.floor(c.b+.5);pal:setColor(i,Color{r=c.r,g=c.g,b=c.b,a=255})end
local sprite=Sprite(w,h,ColorMode.RGB);sprite.layers[1].name='source_mapped_pixels'
local base=Image(sprite.spec);base:clear()
for _,q in ipairs(pixels)do local c=palette[nearest(q,basePaletteSize)];base:drawPixel(q.x,q.y,pc.rgba(c.r,c.g,c.b,255))end
sprite:newCel(sprite.layers[1],1,base,Point(0,0));sprite:setPalette(pal)
local layer=sprite:newLayer();layer.name='pixel_cleanup'
local cleanup=Image(sprite.spec);cleanup:clear()
local fixes=0
if app.params.protect=='wash_soap' then
 for _,q in ipairs(pixels)do
  if q.x>=55 and q.x<=74 and q.y>=41 and q.y<=54 and q.g-q.r>5 then
   local c=palette[nearest(q)];local rgba=pc.rgba(c.r,c.g,c.b,255)
   if rgba~=base:getPixel(q.x,q.y)then cleanup:drawPixel(q.x,q.y,rgba);fixes=fixes+1 end
  end
 end
end
-- Explicit, inspected local edits are supplied separately, never a global smoothing pass.
if app.params.cleanup and app.params.cleanup~=''then
 local edits=dofile(app.params.cleanup)
 for _,e in ipairs(edits)do
  local c=base:getPixel(e[3],e[4]);assert(pc.rgbaA(c)==255,'Cleanup donor must be solid')
  assert(pc.rgbaA(base:getPixel(e[1],e[2]))==255,'Cleanup cannot invent silhouette')
  cleanup:drawPixel(e[1],e[2],c)
 end
end
sprite:newCel(layer,1,cleanup,Point(0,0))
sprite:saveAs(out);sprite:close()
print('SOURCE-MAPPED '..w..'x'..h..' step='..step..' palette='..#palette..' local colour repairs='..fixes)
