-- Native-grid preservation. No spatial averaging, resampling or contrast curve.
-- Every output RGB is an observed source colour; alpha is explicitly binary.
local input=assert(app.params.input)
local output=assert(app.params.output)
local tolerance=tonumber(app.params.tolerance or '12')
local snap=tonumber(app.params.snap or '28')
local coherent=app.params.coherent=='true'
local passes=tonumber(app.params.passes or '0')
local src=Image{fromFile=input}
local pc=app.pixelColor
local W,H=src.width,src.height
local pixels,hist,unique={},{},{}
local function unpackRGB(c)
 return pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c)
end
local function lum(c)return .2126*c.r+.7152*c.g+.0722*c.b end
local function distance(a,b)
 return .25*(a.r-b.r)^2+.5*(a.g-b.g)^2+.25*(a.b-b.b)^2
end
for y=0,H-1 do for x=0,W-1 do
 local raw=src:getPixel(x,y)
 if pc.rgbaA(raw)>=128 then
  local r,g,b=unpackRGB(raw);local key=r*65536+g*256+b
  local p={r=r,g=g,b=b,key=key,x=x,y=y};p.l=lum(p)
  pixels[y*W+x+1]=p
  if not hist[key]then hist[key]={r=r,g=g,b=b,l=p.l,key=key,n=0};unique[#unique+1]=hist[key]end
  hist[key].n=hist[key].n+1
 end
end end
local function at(x,y)
 if x<0 or y<0 or x>=W or y>=H then return nil end
 return pixels[y*W+x+1]
end
-- An error-bounded palette of actual samples, not averaged centroids or a fixed colour cap.
table.sort(unique,function(a,b)if a.n==b.n then return a.key<b.key end return a.n>b.n end)
local palette,mapping={},{}
for _,p in ipairs(unique)do
 local best,score=nil,1e30
 for i,q in ipairs(palette)do
  local d=distance(p,q)
  if d<score and math.abs(p.l-q.l)<=tolerance*.55 and
   math.max(math.abs(p.r-q.r),math.abs(p.g-q.g),math.abs(p.b-q.b))<=tolerance then
   best,score=i,d
  end
 end
 if not best then palette[#palette+1]=p;best=#palette end
 mapping[p.key]=palette[best]
end
local sprite=Sprite(W+2,H+2,ColorMode.RGB)
sprite.layers[1].name='source_reference';sprite.layers[1].isVisible=false
sprite:newCel(sprite.layers[1],1,src,Point(1,1))
local baseLayer=sprite:newLayer();baseLayer.name='native_color_clusters'
local base=Image(sprite.spec);base:clear()
local edgeLayer=sprite:newLayer();edgeLayer.name='edge_side_cleanup'
local edges=Image(sprite.spec);edges:clear()
local changed=0
local function edgeColour(p)
 if not coherent then return p end
 local best,score=nil,1e30
 for _,q in ipairs(palette)do
  local d=distance(p,q)
  if math.abs(p.l-q.l)<=3 and math.max(math.abs(p.r-q.r),math.abs(p.g-q.g),math.abs(p.b-q.b))<=8 and d<score then best,score=q,d end
 end
 if not best then palette[#palette+1]=p;best=p end
 return best
end
local clustered={};local clusterEdits=0
for y=0,H-1 do for x=0,W-1 do local p=at(x,y)
 if p then
  local current=mapping[p.key];local counts,byKey={},{}
  for dy=-1,1 do for dx=-1,1 do local n=at(x+dx,y+dy)
   if n then local c=mapping[n.key];counts[c.key]=(counts[c.key]or 0)+1;byKey[c.key]=c end
  end end
  local best=current;local bestCount=counts[current.key]or 0
  if coherent and bestCount<=2 then
   for key,count in pairs(counts)do local c=byKey[key]
    if count>=5 and (count>bestCount or(count==bestCount and c.key<best.key)) and
     math.abs(p.l-c.l)<=tolerance*.55 and math.max(math.abs(p.r-c.r),math.abs(p.g-c.g),math.abs(p.b-c.b))<=tolerance then best=c;bestCount=count end
   end
  end
  clustered[y*W+x+1]=best
  if best~=current then clusterEdits=clusterEdits+1 end
 end
end end
-- Discrete label regularisation, not a blur: pick an existing colour label under
-- the original per-pixel colour-error bound. Strong source boundaries resist merging.
for iteration=1,passes do
 local nextLabels={}
 for y=0,H-1 do for x=0,W-1 do local p=at(x,y)
  if p then
   local current=clustered[y*W+x+1];local candidates={[current.key]=current};local neighbors={}
   for dy=-1,1 do for dx=-1,1 do
    if dx~=0 or dy~=0 then local n=at(x+dx,y+dy)
     if n then local c=clustered[(y+dy)*W+x+dx+1];candidates[c.key]=c
      neighbors[#neighbors+1]={c=c,weight=math.exp(-distance(p,n)/100)*(dx*dy==0 and 1 or .7)}
     end
    end
   end end
   local best,score=current,1e30
   for _,c in pairs(candidates)do
    if math.abs(p.l-c.l)<=tolerance*.55 and math.max(math.abs(p.r-c.r),math.abs(p.g-c.g),math.abs(p.b-c.b))<=tolerance then
     local cost=distance(p,c)
     for _,n in ipairs(neighbors)do if n.c.key~=c.key then cost=cost+12*n.weight end end
     if cost<score or(cost==score and c.key<best.key)then best,score=c,cost end
    end
   end
   nextLabels[y*W+x+1]=best
  end
 end end
 clustered=nextLabels
end
local function medianSample(a,b,c)
 if not a or not b or not c then return nil end
 local t={a,b,c};table.sort(t,function(u,v)if u.l==v.l then return u.key<v.key end return u.l<v.l end)
 return t[2],t[3].l-t[1].l
end
-- Test coherent two-sided edges in the ORIGINAL, not a blurred or reduced intermediate.
-- Three tangential samples support each side. No recursive propagation, no new extrema.
for y=0,H-1 do for x=0,W-1 do
 local p=at(x,y)
 if p then
  local q=clustered[y*W+x+1];base:drawPixel(x+1,y+1,pc.rgba(q.r,q.g,q.b,255))
  local chosen,confidence=nil,0
  for axis=1,2 do
   local dx,dy=axis==1 and 1 or 0,axis==2 and 1 or 0
   local tx,ty=dy,dx
   local a,ar=medianSample(at(x-2*dx-tx,y-2*dy-ty),at(x-2*dx,y-2*dy),at(x-2*dx+tx,y-2*dy+ty))
   local b,br=medianSample(at(x+2*dx-tx,y+2*dy-ty),at(x+2*dx,y+2*dy),at(x+2*dx+tx,y+2*dy+ty))
   if a and b then
    local span=math.abs(a.l-b.l)
    if span>=24 and ar<=span*.32 and br<=span*.32 then
     local vx,vy,vz=b.r-a.r,b.g-a.g,b.b-a.b
     local denom=vx*vx+vy*vy+vz*vz
     local t=((p.r-a.r)*vx+(p.g-a.g)*vy+(p.b-a.b)*vz)/math.max(1,denom)
     local residual=(p.r-a.r-t*vx)^2+(p.g-a.g-t*vy)^2+(p.b-a.b-t*vz)^2
     -- Do not cross material hues, touch an extremum, or turn ambiguity into arbitrary noise.
     if t>.08 and t<.92 and math.abs(t-.5)>.08 and residual<100 then
      local target=t<.5 and a or b
      local shift=math.abs(target.l-p.l)
      local support=0
      for k=-1,1,2 do local n=at(x+k*tx,y+k*ty)
       if n and distance(n,target)<distance(n,t<.5 and b or a)then support=support+1 end
      end
      local strength=span-ar-br
      if support==2 and shift<=snap and shift>=3 and strength>confidence then
       chosen=target;confidence=strength
      end
     end
    end
   end
  end
  if chosen then
   -- Keep the observed edge colour itself: palette reduction must not soften it again.
   chosen=edgeColour(chosen)
   local c=pc.rgba(chosen.r,chosen.g,chosen.b,255)
   if c~=base:getPixel(x+1,y+1)then edges:drawPixel(x+1,y+1,c);changed=changed+1 end
  end
 end
end end
sprite:newCel(baseLayer,1,base,Point(0,0));sprite:newCel(edgeLayer,1,edges,Point(0,0))
local used={};local swatches={}
for y=0,H+1 do for x=0,W+1 do
 local c=edges:getPixel(x,y);if pc.rgbaA(c)==0 then c=base:getPixel(x,y)end
 if pc.rgbaA(c)==255 and not used[c]then used[c]=true;swatches[#swatches+1]=c end
end end
table.sort(swatches,function(a,b)
 local ar,ag,ab=unpackRGB(a);local br,bg,bb=unpackRGB(b)
 local al=.2126*ar+.7152*ag+.0722*ab;local bl=.2126*br+.7152*bg+.0722*bb
 if al==bl then return a<b end return al<bl
end)
local pal=Palette(#swatches+1);pal:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(swatches)do local r,g,b=unpackRGB(c);pal:setColor(i,Color{r=r,g=g,b=b,a=255})end
sprite:setPalette(pal)
sprite:saveAs(output)
print('CRISP_NATIVE '..W..'x'..H..' + 1px border; palette='..#palette..' edgeEdits='..changed..' clusterEdits='..clusterEdits..' tolerance='..tolerance..' snap='..snap..' passes='..passes)
sprite:close()
