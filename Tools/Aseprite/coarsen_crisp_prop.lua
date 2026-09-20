-- Source-driven grid experiment. The approved crisp preparation is freshly
-- reproduced from the original; this pass changes grid pitch only, never RGB contrast.
local pc=app.pixelColor
local raw=Image{fromFile=assert(app.params.input)}
local prepared=app.open(assert(app.params.prepared))
local full=Image(prepared.spec);full:drawSprite(prepared,1)
assert(full.width==raw.width+2 and full.height==raw.height+2)
prepared:close()
local step=tonumber(assert(app.params.step));assert(step>=1 and step<=4)
local w,h=math.ceil(raw.width/step),math.ceil(raw.height/step)
local s=Sprite(w+2,h+2,ColorMode.RGB)
s.layers[1].name='center_sample_reference';s.layers[1].isVisible=false
local reference=Image(s.spec);reference:clear()
local layer=s:newLayer();layer.name='coverage_selected_pixels'
local im=Image(s.spec);im:clear()
local function dist(a,b)
 return .25*(pc.rgbaR(a)-pc.rgbaR(b))^2+.5*(pc.rgbaG(a)-pc.rgbaG(b))^2+.25*(pc.rgbaB(a)-pc.rgbaB(b))^2
end
local changed=0;local used={}
for y=0,h-1 do for x=0,w-1 do
 local x0,y0=x*step,y*step
 local x1,y1=math.min(raw.width,(x+1)*step),math.min(raw.height,(y+1)*step)
 local cx,cy=math.floor((x0+x1)/2),math.floor((y0+y1)/2)
 local center=full:getPixel(cx+1,cy+1)
 reference:drawPixel(x+1,y+1,center)
 local samples={};local area=0
 for sy=math.floor(y0),math.ceil(y1)-1 do for sx=math.floor(x0),math.ceil(x1)-1 do
  local weight=(math.min(x1,sx+1)-math.max(x0,sx))*(math.min(y1,sy+1)-math.max(y0,sy))
  local c=full:getPixel(sx+1,sy+1)
  if pc.rgbaA(c)==255 and weight>0 then
   samples[#samples+1]={c=c,weight=weight,center=(sx-cx)^2+(sy-cy)^2};area=area+weight
  end
 end end
 local result=0
 if area>0 and area>=(x1-x0)*(y1-y0)*.5 then
  -- Weighted colour-mode membership; this is coverage counting, NOT RGB averaging.
  local best,bestScore=nil,-1
  for _,a in ipairs(samples)do
   local score=0
   for _,b in ipairs(samples)do if dist(a.c,b.c)<=144 then score=score+b.weight end end
   score=score+.08*a.weight/(1+a.center)
   if score>bestScore or(score==bestScore and(a.center<best.center or(a.center==best.center and a.c<best.c)))then best,bestScore=a,score end
  end
  result=best.c;im:drawPixel(x+1,y+1,result);used[result]=true
 end
 if result~=center then changed=changed+1 end
end end
s:newCel(s.layers[1],1,reference,Point(0,0));s:newCel(layer,1,im,Point(0,0))
local list={};for c in pairs(used)do list[#list+1]=c end;table.sort(list)
local pal=Palette(#list+1);pal:setColor(0,Color{r=0,g=0,b=0,a=0})
for i,c in ipairs(list)do pal:setColor(i,Color{r=pc.rgbaR(c),g=pc.rgbaG(c),b=pc.rgbaB(c),a=255})end
s:setPalette(pal);s:saveAs(assert(app.params.output));s:close()
print('GRID '..step..' native='..(w+2)..'x'..(h+2)..' colours='..#list..' decisionsDifferentFromCentre='..changed)
