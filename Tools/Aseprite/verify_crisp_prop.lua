local s=assert(app.activeSprite)
local src=Image{fromFile=assert(app.params.input)}
local expected=Image{fromFile=assert(app.params.png)}
local pc=app.pixelColor
assert(s.colorMode==ColorMode.RGB and #s.frames==1 and #s.layers==3)
assert(s.width==src.width+2 and s.height==src.height+2)
assert(s.layers[1].name=='source_reference' and not s.layers[1].isVisible)
assert(s.layers[2].name=='native_color_clusters' and s.layers[2].isVisible)
assert(s.layers[3].name=='edge_side_cleanup' and s.layers[3].isVisible)
local composite=Image(s.spec);composite:drawSprite(s,1)
for y=0,s.height-1 do for x=0,s.width-1 do
 local c=composite:getPixel(x,y)
 assert(c==expected:getPixel(x,y),'Export/composite mismatch')
 local a=pc.rgbaA(c);assert(a==0 or a==255)
 if x==0 or y==0 or x==s.width-1 or y==s.height-1 then assert(a==0)end
end end
-- Read the stored reference cel at sprite coordinates, including Aseprite trimming.
local ref=s.layers[1]:cel(1)
for y=0,src.height-1 do for x=0,src.width-1 do
 local rx,ry=x+1-ref.position.x,y+1-ref.position.y
 local c=0
 if rx>=0 and ry>=0 and rx<ref.image.width and ry<ref.image.height then c=ref.image:getPixel(rx,ry)end
 local original=src:getPixel(x,y)
 assert(pc.rgbaA(c)==pc.rgbaA(original),'Reference alpha mismatch')
 if pc.rgbaA(original)>0 then assert(c==original,'Reference colour mismatch')end
 local out=composite:getPixel(x+1,y+1)
 assert((pc.rgbaA(out)==255)==(pc.rgbaA(original)>=128),'Silhouette mismatch')
end end
print('VERIFIED reference, layers, dimensions, binary alpha, exact mask and composite')
