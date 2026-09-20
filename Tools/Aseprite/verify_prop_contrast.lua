local sprite=assert(app.activeSprite)
local baseline=Image{fromFile=assert(app.params.baseline)}
local strength=assert(app.params.strength)
assert(#sprite.layers==3 and #sprite.frames==1,'Expected preserved layers + contrast layer')
assert(sprite.layers[1].name=='source_mapped_pixels' and sprite.layers[2].name=='pixel_cleanup')
local layer=sprite.layers[3];assert(layer.name=='contrast_'..strength)
assert(sprite.width==baseline.width and sprite.height==baseline.height)
layer.isVisible=false
local restored=Image(sprite.spec);restored:drawSprite(sprite,1)
for y=0,baseline.height-1 do for x=0,baseline.width-1 do
 assert(restored:getPixel(x,y)==baseline:getPixel(x,y),'Underlying baseline altered')
end end
layer.isVisible=true
local final=Image(sprite.spec);final:drawSprite(sprite,1)
for y=0,baseline.height-1 do for x=0,baseline.width-1 do
 assert(app.pixelColor.rgbaA(final:getPixel(x,y))==app.pixelColor.rgbaA(baseline:getPixel(x,y)),'Alpha altered')
end end
print('PASS: contrast layer toggle restores exact baseline; silhouette unchanged')
