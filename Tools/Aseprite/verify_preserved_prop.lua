local sprite=assert(app.activeSprite)
assert(#sprite.frames==1 and #sprite.layers==2,'Unexpected source structure')
assert(sprite.layers[1].name=='source_mapped_pixels' and sprite.layers[2].name=='pixel_cleanup','Wrong layers')
assert(sprite.colorMode==ColorMode.RGB,'Expected RGB source')
local image=Image(sprite.spec);image:drawSprite(sprite,1)
local colors={};local count=0
for y=0,sprite.height-1 do for x=0,sprite.width-1 do
 local c=image:getPixel(x,y);local a=app.pixelColor.rgbaA(c)
 assert(a==0 or a==255,'Partial alpha')
 if a==255 then
  assert(x>0 and y>0 and x<sprite.width-1 and y<sprite.height-1,'Opaque border')
  if not colors[c]then colors[c]=true;count=count+1 end
 end
end end
assert(sprite.width==tonumber(app.params.width) and sprite.height==tonumber(app.params.height),'Dimensions')
print('ROUND-TRIP SOURCE CHECK '..sprite.width..'x'..sprite.height..' colours='..count..' layers=2')
