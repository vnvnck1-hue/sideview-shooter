local s=assert(app.activeSprite)
local expected=Image{fromFile=assert(app.params.png)}
assert(s.colorMode==ColorMode.RGB and #s.frames==1 and #s.layers==2)
assert(s.layers[1].name=='center_sample_reference' and not s.layers[1].isVisible)
assert(s.layers[2].name=='coverage_selected_pixels' and s.layers[2].isVisible)
assert(s.width==expected.width and s.height==expected.height)
local image=Image(s.spec);image:drawSprite(s,1)
for y=0,s.height-1 do for x=0,s.width-1 do
 local c=image:getPixel(x,y);assert(c==expected:getPixel(x,y))
 local a=app.pixelColor.rgbaA(c);assert(a==0 or a==255)
 if x==0 or y==0 or x==s.width-1 or y==s.height-1 then assert(a==0)end
end end
print('VERIFIED grid layers, dimensions, alpha, border and PNG pixels')
