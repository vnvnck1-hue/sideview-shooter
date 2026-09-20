-- Scoped geometry contracts for batch2/r4; not a general art-quality score.
local sprite=assert(app.activeSprite)
local name=assert(app.params.name)
local img=Image(sprite.spec);img:drawSprite(sprite,1)
local ink=app.pixelColor.rgba(23,25,35,255)
local function line(x,y,x2,y2)
 for yy=y,y2 do for xx=x,x2 do assert(img:getPixel(xx,yy)==ink,"Broken structural edge at "..xx..","..yy)end end
end
local function equal(x,y,x2,y2,w,h)
 for dy=0,h-1 do for dx=0,w-1 do assert(img:getPixel(x+dx,y+dy)==img:getPixel(x2+dx,y2+dy),"Repeated part mismatch")end end
end
local checks={
 microscope_station=function()
  line(51,42,51,55);line(8,43,8,55);line(39,25,39,31)
  line(24,22,26,22) -- centred objective outlet, x25
  assert(img:getPixel(25,26)~=0,"Missing aligned specimen")
  for x=23,27 do for y=23,24 do assert(app.pixelColor.rgbaA(img:getPixel(x,y))==0,"Optical opening filled")end end
 end,
 sample_cart=function()
  equal(8,20,8,36,45,3) -- both front lips: same thickness, width and shading
  equal(9,40,47,40,7,7) -- identical wheel masks and same axle height
  equal(10,25,48,25,4,8) -- two uprights, including finish, same width
  line(58,12,58,19);line(58,23,58,32)
 end,
 server_rack=function()
  line(55,6,55,83);line(6,5,6,81)
  for _,m in ipairs({{12,12},{26,17},{45,7},{54,7},{63,15}})do
   -- One shared left/right slot boundary, no displaced module.
   for y=m[1],m[1]+m[2]-1 do
    local c=app.pixelColor.rgba(39,41,56,255)
    assert(img:getPixel(17,y)==c and img:getPixel(48,y)==c,"Slot boundary mismatch")
   end
  end
  equal(20,65,35,65,11,11)
 end
}
local check=assert(checks[name]);check()
-- Negative control: prove a deliberately broken shape is rejected.
local fixtures={microscope_station={24,22},sample_cart={11,42},server_rack={55,40}}
local f=fixtures[name];local old=img:getPixel(f[1],f[2]);img:drawPixel(f[1],f[2],app.pixelColor.rgba(255,0,255,255))
local ok=pcall(check);assert(not ok,"Geometry negative control failed")
img:drawPixel(f[1],f[2],old);check()
print("GEOMETRY CONTRACT + NEGATIVE CONTROL PASS: "..name)
