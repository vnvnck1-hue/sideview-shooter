-- Source-preserving production pass for the three selected creature designs.
-- AI-authored poses are immutable inputs. Sampling selects source pixels, never averages.
local root=assert(app.params.root)
local id=assert(app.params.id)
local pc=app.pixelColor
local function path(...) return app.fs.joinPath(...) end
local sourceDir=path(root,'Assets','Generated','CreatureProductionV1','sources')
local out=path(root,'Assets','Generated','CreatureProductionV1','processed',id)
app.fs.makeAllDirectories(out)
local config={
 CeilingBell={w=144,h=192,anchor={72,8},mode='ceiling',pitch=3,
  names={'idle','anticipate','strike','hold','retract','close','hurt','death'},
  times={{240,240,240,240},{120,120,160,220},{60,60,80,140},{150,150,150,150},{100,100,120,140},{130,130,150,200},{70,90,110,150},{120,150,180,650}},
  loops={true,false,false,true,false,false,false,false}},
 RingSpine={w=176,h=112,anchor={44,104},mode='ground',pitch=3,
  names={'idle','roll','uncoil','lash','recoil','coil','hurt','death'},
  times={{200,200,200,200},{80,80,80,80},{90,100,110,140},{120,90,60,130},{100,100,120,150},{120,120,140,180},{70,90,110,150},{120,150,200,650}},
  loops={true,true,false,false,false,false,false,false}},
 SeamAmbusher={w=144,h=160,anchor={12,52},mode='wall',pitch=3,
  names={'dormant','emerge','snap','hold','release','withdraw','hurt','death'},
  times={{300,250,300,250},{150,150,160,220},{90,70,60,160},{160,160,160,160},{110,110,140,180},{150,150,160,220},{70,90,110,150},{120,160,220,650}},
  loops={true,false,false,true,false,false,false,false}}
}
local cfg=assert(config[id],id)
local overrideFile=path(root,'Assets','Generated','CreatureProductionV1','adjustments.json')
local overrides={}
local f=io.open(overrideFile,'r');if f then local str=f:read('*a'):gsub('^\239\187\191','');overrides=json.decode(str);f:close() end
local spec=overrides[id]or{}
if spec.pitch then cfg.pitch=spec.pitch end
local function rgba(r,g,b) return pc.rgba(r,g,b,255) end
local function dist(a,b) return .30*(a.r-b.r)^2+.52*(a.g-b.g)^2+.18*(a.b-b.b)^2 end
local function rgb(c)return {r=pc.rgbaR(c),g=pc.rgbaG(c),b=pc.rgbaB(c)}end
local function writeJson(file,obj)local h=assert(io.open(file,'w'));h:write(json.encode(obj));h:close()end
local function bbox(im)
 local x0,y0,x1,y1=im.width,im.height,-1,-1
 for y=0,im.height-1 do for x=0,im.width-1 do
  if pc.rgbaA(im:getPixel(x,y))>=128 then x0=math.min(x0,x);y0=math.min(y0,y);x1=math.max(x1,x);y1=math.max(y1,y)end
 end end
 assert(x1>=x0,'Empty source/frame');return {x0,y0,x1+1,y1+1}
end
local sources={Image{fromFile=path(sourceDir,id..'_A.png')},Image{fromFile=path(sourceDir,id..'_B.png')}}
local frames,hist,colors={},{},{}
for clip=1,8 do
 local batch=clip<=4 and 1 or 2
 local src=sources[batch]
 local row=(clip-1)%4
 local cw,ch=src.width/4,src.height/4
 for col=0,3 do
  local key=cfg.names[clip]..'_'..string.format('%02d',col+1)
  local ov=(spec.frames or {})[key]or{}
  local rect=ov.rect or {math.floor(col*cw),math.floor(row*ch),math.floor((col+1)*cw),math.floor((row+1)*ch)}
  local cell
  if ov.file then cell=Image{fromFile=ov.file}
  else cell=Image(rect[3]-rect[1],rect[4]-rect[2],ColorMode.RGB);cell:drawImage(src,Point(-rect[1],-rect[2]))end
  local b=bbox(cell)
  local ax,ay
  if cfg.mode=='ceiling' then
   local sum,n=0,0
   for y=b[2],math.min(b[2]+5,b[4]-1)do for x=b[1],b[3]-1 do if pc.rgbaA(cell:getPixel(x,y))>=128 then sum=sum+x;n=n+1 end end end
   ax=sum/math.max(n,1);ay=b[2]
  elseif cfg.mode=='wall' then
   local sum,n=0,0
   for x=b[1],math.min(b[1]+5,b[3]-1)do for y=b[2],b[4]-1 do if pc.rgbaA(cell:getPixel(x,y))>=128 then sum=sum+y;n=n+1 end end end
   ax=b[1];ay=sum/math.max(n,1)
  else
   ax=(clip==1 or clip==2 or clip==7 or (clip==6 and col==3))and((b[1]+b[3]-1)/2)or(b[1]+30*cfg.pitch)
   ay=b[4]-1
  end
  if ov.anchor then ax,ay=ov.anchor[1],ov.anchor[2]end
  local pitch=ov.pitch or (batch==2 and spec.pitchB)or cfg.pitch
  local target=ov.target or cfg.anchor
  local im=Image(cfg.w,cfg.h,ColorMode.RGB);im:clear()
  local clipped=0
  -- Inverse nearest sample anchored to a stable attachment point. No bbox fit.
  for y=0,cfg.h-1 do for x=0,cfg.w-1 do
   local sx=math.floor(ax+(x-target[1])*pitch+.5)
   local sy=math.floor(ay+(y-target[2])*pitch+.5)
   if sx>=0 and sx<cell.width and sy>=0 and sy<cell.height then
    local c=cell:getPixel(sx,sy)
    if pc.rgbaA(c)>=128 then
     c=rgba(pc.rgbaR(c),pc.rgbaG(c),pc.rgbaB(c));im:drawPixel(x,y,c)
     local p=rgb(c);local k=math.floor(p.r/8)*1024+math.floor(p.g/8)*32+math.floor(p.b/8)
     if not hist[k]then p.n=0;p.c=c;hist[k]=p;colors[#colors+1]=p end
     hist[k].n=hist[k].n+1
    end
   end
  end end
  -- Test source silhouette extrema against canvas separately from sampled pixels.
  local projected={target[1]+(b[1]-ax)/pitch,target[2]+(b[2]-ay)/pitch,target[1]+(b[3]-ax)/pitch,target[2]+(b[4]-ay)/pitch}
  if projected[1]<1 or projected[2]<1 or projected[3]>cfg.w-1 or projected[4]>cfg.h-1 then clipped=1 end
  frames[#frames+1]={image=im,key=key,clip=clip,localFrame=col+1,ms=cfg.times[clip][col+1],sourceRect=rect,sourceBounds=b,sourceAnchor={ax,ay},pitch=pitch,projectedBounds=projected,clipped=clipped}
 end
end
-- Reuse authored poses at state joins, instead of introducing a new anatomy per sheet.
local original=frames
local sequence={}
for i=1,8 do sequence[i]={};for j=1,4 do sequence[i][j]=original[(i-1)*4+j]end end
local function copyPose(fr,ms)
 local r={};for k,v in pairs(fr)do r[k]=v end;r.image=Image(fr.image);r.ms=ms or fr.ms;return r
end
local function reversed(indices,times)
 local r={};for j,i in ipairs(indices)do r[j]=copyPose(original[i],times[j]or times[#times])end;return r
end
if id=='CeilingBell' then
 sequence[5]=reversed({12,11,10,9},{100,90,100,140})
 sequence[6]=reversed({8,7,6,5,1},{100,100,130,140,180})
 -- Local bend below the fixed tendon. Keep the canonical shell, not B's alternate shell.
 sequence[7]={}
 for j,amount in ipairs({-3,2,-1,0})do
  local fr=copyPose(original[1],cfg.times[7][j]);local im=Image(cfg.w,cfg.h,ColorMode.RGB);im:clear()
  for y=0,cfg.h-1 do
   local shift=math.floor(amount*math.min(1,math.max(0,(y-17)/45))+.5)
   for x=0,cfg.w-1 do local sx=x-shift;if sx>=0 and sx<cfg.w then im:drawPixel(x,y,fr.image:getPixel(sx,y))end end
  end
  fr.image=im;fr.derivation='canonical idle with anchored tendon bend';sequence[7][j]=fr
 end
elseif id=='RingSpine' then
 sequence[2]={}
 local base=original[1];local b=bbox(base.image);local cx,cy=(b[1]+b[3]-1)/2,(b[2]+b[4]-1)/2
 for j=0,11 do
  local fr=copyPose(base,65);local im=Image(cfg.w,cfg.h,ColorMode.RGB);im:clear();local angle=j*math.pi/6
  for y=0,cfg.h-1 do for x=0,cfg.w-1 do
   local dx,dy=x-cx,y-cy;local sx=math.floor(cx+dx*math.cos(angle)+dy*math.sin(angle)+.5);local sy=math.floor(cy-dx*math.sin(angle)+dy*math.cos(angle)+.5)
   if sx>=0 and sy>=0 and sx<cfg.w and sy<cfg.h then im:drawPixel(x,y,base.image:getPixel(sx,sy))end
  end end
  fr.image=im;fr.derivation='canonical ring rigid rotation '..(j*30)..' degrees';sequence[2][j+1]=fr
 end
 sequence[5]=reversed({16,15,14,13,12},{80,90,100,120,150})
 sequence[6]=reversed({12,11,10,9,1},{100,110,120,140,180})
elseif id=='SeamAmbusher' then
 sequence[5]=reversed({12,11,10,9,8},{100,100,120,140,160})
 sequence[6]=reversed({8,7,6,5,1},{120,130,140,150,200})
end
frames={};local maxFrames=0
for clip,list in ipairs(sequence)do
 maxFrames=math.max(maxFrames,#list)
 for j,srcfr in ipairs(list)do local fr=copyPose(srcfr);fr.clip=clip;fr.localFrame=j;fr.key=cfg.names[clip]..'_'..string.format('%02d',j);frames[#frames+1]=fr end
end
-- A shared 16-colour medoid palette from source samples. Reserve colours for each
-- material so a small green weak organ is not outvoted by ivory area.
table.sort(colors,function(a,b)if a.n==b.n then return a.c<b.c else return a.n>b.n end end)
local buckets={{},{},{}}
for _,p in ipairs(colors)do
 local group=(p.r>p.g*1.38 and p.r>p.b*1.3)and 1 or ((p.g>p.r*.82 and p.g>p.b*1.5)and 3 or 2)
 table.insert(buckets[group],p)
end
local palette={}
for group,limit in ipairs({6,6,4})do
local candidates=buckets[group];if #candidates==0 then candidates=colors end
local localPal={candidates[1]}
for n=2,limit do
 local best,score=nil,-1
 for _,p in ipairs(candidates)do
  local d=math.huge;for _,q in ipairs(localPal)do d=math.min(d,dist(p,q))end
  local s=d*math.sqrt(p.n)
  if s>score then score=s;best=p end
 end
 localPal[#localPal+1]=best
end
for iteration=1,8 do
 local groups={};for i=1,#localPal do groups[i]={}end
 for _,p in ipairs(candidates)do local bi,bd=1,math.huge;for i,q in ipairs(localPal)do local d=dist(p,q);if d<bd then bd=d;bi=i end end;table.insert(groups[bi],p)end
 for i,g in ipairs(groups)do if #g>0 then
  local mean={r=0,g=0,b=0};local n=0
  for _,p in ipairs(g)do mean.r=mean.r+p.r*p.n;mean.g=mean.g+p.g*p.n;mean.b=mean.b+p.b*p.n;n=n+p.n end
  mean.r=mean.r/n;mean.g=mean.g/n;mean.b=mean.b/n
  local best,bd=g[1],math.huge;for _,p in ipairs(g)do local d=dist(p,mean);if d<bd then best=p;bd=d end end;localPal[i]=best
 end end
end
for _,p in ipairs(localPal)do table.insert(palette,p)end
end
table.sort(palette,function(a,b)return a.r*.2126+a.g*.7152+a.b*.0722<b.r*.2126+b.g*.7152+b.b*.0722 end)
local mapping={}
local function nearest(c)
 if mapping[c]then return mapping[c]end
 local p=rgb(c);local best,bd=palette[1],math.huge
 for _,q in ipairs(palette)do local d=dist(p,q);if d<bd then best=q;bd=d end end
 mapping[c]=best.c;return best.c
end
local sprite=Sprite(cfg.w,cfg.h,ColorMode.RGB)
local reference=sprite.layers[1];reference.name='sampled_source_reference';reference.isVisible=false
local colorLayer=sprite:newLayer();colorLayer.name='shared_palette_clusters'
local cleanupLayer=sprite:newLayer();cleanupLayer.name='local_cluster_cleanup'
local pal=Palette(17);pal:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,p in ipairs(palette)do pal:setColor(i,Color{r=p.r,g=p.g,b=p.b,a=255})end
sprite:setPalette(pal)
local metadata={schemaVersion=1,id=id,cell={cfg.w,cfg.h},pivot=cfg.anchor,units='native art pixels',suggestedWorldScale=4,gameImported=false,palette={},clips={},frames={},losses={'High-frequency concept texture reduced to native pixel clusters; source pose sheets preserved separately.','Generated pose topology and scale reviewed visually; exact physics geometry is not provided.'}}
for _,p in ipairs(palette)do table.insert(metadata.palette,{p.r,p.g,p.b})end
local allSheet=Image(cfg.w*maxFrames,cfg.h*8,ColorMode.RGB);allSheet:clear()
for i,fr in ipairs(frames)do
 if i>1 then sprite:newEmptyFrame()end
 sprite.frames[i].duration=fr.ms/1000
 sprite:newCel(reference,i,fr.image,Point(0,0))
 local clustered=Image(sprite.spec);clustered:clear()
 for y=0,cfg.h-1 do for x=0,cfg.w-1 do local c=fr.image:getPixel(x,y);if pc.rgbaA(c)>0 then clustered:drawPixel(x,y,nearest(c))end end end
 local clean=Image(clustered);local changes=Image(sprite.spec);changes:clear();local changed=0
 -- Remove isolated interior colour specks only, never modify alpha or weak organs.
 for y=1,cfg.h-2 do for x=1,cfg.w-2 do
  local c=clustered:getPixel(x,y)
  if pc.rgbaA(c)>0 then
   local p=rgb(c);local green=p.g>p.r*.85 and p.g>p.b*1.3
   local counts={};local opaque=0
   for dy=-1,1 do for dx=-1,1 do if dx~=0 or dy~=0 then local q=clustered:getPixel(x+dx,y+dy);if pc.rgbaA(q)>0 then opaque=opaque+1;counts[q]=(counts[q]or 0)+1 end end end end
   if not green and opaque==8 and not counts[c]then
    local best,n=c,0;for q,count in pairs(counts)do if count>n or(count==n and q<best)then best=q;n=count end end
    if n>=5 and dist(rgb(best),p)<500 then clean:drawPixel(x,y,best);changes:drawPixel(x,y,best);changed=changed+1 end
   end
  end
 end end
 sprite:newCel(colorLayer,i,clustered,Point(0,0));sprite:newCel(cleanupLayer,i,changes,Point(0,0))
 local b=bbox(clean);local gx,gy,gn=0,0,0
 for y=0,cfg.h-1 do for x=0,cfg.w-1 do local c=clean:getPixel(x,y);local p=rgb(c)
  if pc.rgbaA(c)>0 and p.g>p.r*.86 and p.g>p.b*1.35 and p.g>60 then gx=gx+x;gy=gy+y;gn=gn+1 end
 end end
 local name=cfg.names[fr.clip];local folder=path(out,'frames',name);app.fs.makeAllDirectories(folder)
 clean:saveAs(path(folder,fr.key..'.png'))
 allSheet:drawImage(clean,Point((fr.localFrame-1)*cfg.w,(fr.clip-1)*cfg.h))
 local weak=gn>2 and {math.floor(gx/gn+.5),math.floor(gy/gn+.5)}or nil
 table.insert(metadata.frames,{index=i-1,key=fr.key,clip=name,localFrame=fr.localFrame-1,durationMs=fr.ms,sourceRect=fr.sourceRect,sourceAnchor=fr.sourceAnchor,samplePitch=fr.pitch,bounds=b,projectedBounds=fr.projectedBounds,clipped=fr.clipped,cleanupPixels=changed,weakPointVisualCenter=weak,derivation=fr.derivation})
end
local offset=1
for clip,name in ipairs(cfg.names)do
 local count=#sequence[clip];local first=offset;local last=first+count-1;offset=last+1
 local tag=sprite:newTag(first,last);tag.name=name
 local sheet=Image(cfg.w*count,cfg.h,ColorMode.RGB);sheet:clear()
 local times={}
 for j=0,count-1 do local im=Image(sprite.spec);im:drawSprite(sprite,first+j);sheet:drawImage(im,Point(j*cfg.w,0));table.insert(times,frames[first+j].ms)end
 app.fs.makeAllDirectories(path(out,'sheets'));sheet:saveAs(path(out,'sheets',name..'.png'))
 table.insert(metadata.clips,{name=name,from=first-1,to=last-1,loop=cfg.loops[clip],durationsMs=times,sheet='sheets/'..name..'.png'})
end
sprite:saveAs(path(out,id..'.aseprite'))
allSheet:saveAs(path(out,'all_clips.png'))
writeJson(path(out,'animation.json'),metadata)
sprite:close()
print('BUILT '..id..': '..#frames..' frames, 8 tags, shared 16-color palette')
