-- Research facility second batch. Native coordinates only; staging output only.
local out=assert(app.params.output_root,"output_root required")
local revision=tonumber(app.params.revision or "1")
assert(revision>=1 and revision<=3,"Unsupported revision")
local hex={"171923","272938","3e414b","656264","8a8580","a8a293","c5c0ab","634d43","96704a","b69863","17393e","255b60","438382","8fb5a4","dca64e","974e44"}
local colors={}
for i,h in ipairs(hex)do colors[i]=app.pixelColor.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255)end
local I
local function p(x,y,c)
 assert(x==math.floor(x) and y==math.floor(y),"Non-integer coordinate")
 assert(x>=0 and x<I.width and y>=0 and y<I.height,"Pixel outside canvas")
 I:drawPixel(x,y,colors[c])
end
local function r(x,y,xx,yy,c)for j=y,yy do for i=x,xx do p(i,j,c)end end end
local function l(x,y,xx,yy,c)
 local dx,dy=math.abs(xx-x),-math.abs(yy-y);local sx,sy=x<xx and 1 or -1,y<yy and 1 or -1;local e=dx+dy
 while true do p(x,y,c);if x==xx and y==yy then break end;local ee=2*e
 if ee>=dy then e=e+dy;x=x+sx end;if ee<=dx then e=e+dx;y=y+sy end end
end
local function poly(v,c)
 local low,high=999,-999;for _,a in ipairs(v)do low=math.min(low,a[2]);high=math.max(high,a[2])end
 for y=low,high do local hits={};local scan=y+.5
 for n,a in ipairs(v)do local b=v[n%#v+1];if (a[2]<=scan and b[2]>scan)or(b[2]<=scan and a[2]>scan)then hits[#hits+1]=a[1]+(scan-a[2])*(b[1]-a[1])/(b[2]-a[2])end end
 table.sort(hits);for n=1,#hits-1,2 do r(math.ceil(hits[n]),y,math.floor(hits[n+1]),y,c)end end
 for n,a in ipairs(v)do local b=v[n%#v+1];l(a[1],a[2],b[1],b[2],c)end
end
local function bolt(x,y)r(x,y,x+2,y+2,2);r(x,y,x+1,y,6);p(x+1,y+1,4)end
local function bevel(x,y,w,h,c)
 r(x,y,x+w-1,y+h-1,2);r(x+1,y+1,x+w-2,y+h-2,c)
 r(x+1,y+1,x+w-3,y+1,5);r(x+w-2,y+2,x+w-2,y+h-2,3)
end
local function bottle(x,y,h,c)
 r(x+1,y,x+5,y+1,2);r(x+2,y,x+4,y,6);r(x+2,y+2,x+4,y+3,12)
 poly({{x+1,y+4},{x+5,y+4},{x+6,y+5},{x+6,y+h},{x,y+h},{x,y+5}},11)
 r(x+1,y+5,x+5,y+h-1,c);r(x+1,y+5,x+2,y+h-2,13);r(x+2,y+5,x+2,y+7,14)
end
local function wheel(x,y)
 poly({{x+2,y},{x+6,y},{x+8,y+2},{x+8,y+6},{x+6,y+8},{x+2,y+8},{x,y+6},{x,y+2}},1)
 r(x+2,y+1,x+6,y+6,3);r(x+2,y+1,x+5,y+2,4);r(x+3,y+3,x+5,y+5,1);r(x+3,y+3,x+4,y+4,5)
end
local function caster(x)
 poly({{x+2,40},{x+6,40},{x+8,42},{x+8,44},{x+6,46},{x+2,46},{x,44},{x,42}},1)
 poly({{x+2,41},{x+5,41},{x+7,43},{x+5,45},{x+2,45},{x+1,43}},3)
 r(x+2,41,x+4,41,4);r(x+3,42,x+5,44,2);r(x+3,42,x+4,43,5)
end
local function microscope(s)
 I=s.structure
 -- Pedestal and equipment table: top, front, narrow left plane.
 poly({{8,38},{48,38},{48,54},{44,56},{7,56},{4,53},{4,41}},1)
 poly({{5,41},{10,40},{10,53},{7,54},{5,52}},3);r(7,42,8,50,4)
 r(11,40,46,53,4);r(11,41,45,51,5);r(11,52,45,53,3)
 bevel(13,42,18,10,5);r(17,44,26,46,2);r(18,44,25,44,6)
 bevel(32,42,13,10,3)
 poly({{7,34},{45,34},{51,37},{51,40},{4,40},{2,38}},1)
 poly({{7,35},{44,35},{49,37},{5,37}},6);r(5,38,49,38,7);r(5,39,49,39,8)
 r(8,54,14,56,2);r(39,54,46,56,2)
 -- Microscope C-arm, an open optical path and a separate stage.
 poly({{32,12},{38,14},{40,29},{36,34},{24,34},{22,31},{31,29},{32,23},{30,19}},1)
 poly({{33,14},{36,15},{38,27},{34,31},{25,32},{32,28},{34,22},{32,18}},4)
 poly({{33,14},{34,15},{36,23},{35,28},{32,30},{33,26},{34,21},{32,17}},6)
 poly({{24,7},{31,9},{34,14},{31,18},{24,17},{20,12}},1)
 poly({{24,8},{30,10},{32,14},{29,16},{24,15},{22,12}},5)
 l(24,9,29,11,7);r(25,17,29,19,3);r(25,18,28,18,6)
 r(23,19,25,22,2);r(27,19,29,23,2);r(23,19,24,21,6);r(27,20,28,22,5)
 poly({{13,4},{16,2},{24,8},{23,12},{20,11}},1)
 poly({{16,4},{22,8},{22,10},{19,8}},4);l(16,4,21,7,6)
 poly({{20,3},{23,2},{28,7},{26,10}},1);l(22,4,26,7,5)
 poly({{15,24},{30,24},{34,26},{32,28},{15,28},{12,26}},1)
 poly({{16,25},{29,25},{31,26},{15,26}},5);r(15,27,31,27,3)
 r(23,28,27,30,2);r(24,28,26,29,7)
 poly({{21,31},{36,31},{40,34},{39,35},{18,35},{18,33}},2)
 r(22,32,35,33,5);r(20,34,37,34,6)
 -- Focus wheel, with mass rather than a single dot.
 poly({{36,19},{39,19},{42,22},{42,25},{39,27},{36,27},{34,25},{34,22}},1)
 r(36,21,39,25,4);r(36,21,38,22,6);r(37,23,39,25,3)
 -- Compact control wedge on left; does not fill the microscope opening.
 poly({{6,29},{12,28},{15,32},{15,35},{5,35},{5,31}},1)
 poly({{7,30},{11,29},{13,32},{6,32}},5);r(6,33,13,34,3)
 I=s.material;r(7,30,10,31,11);r(8,30,10,30,13)
 I=s.functionals;r(21,25,26,25,14);r(20,26,26,26,12)
 r(34,44,41,46,11);r(35,44,39,45,13);r(41,48,42,49,15)
 r(34,48,37,49,2);r(35,48,36,48,5)
 I=s.shadow;r(7,57,16,57,1);r(38,57,48,57,1)
end
local function cart(s)
 I=s.structure
 -- Two independent trays, with a visible gap and push handle.
 r(8,21,12,39,1);r(9,23,11,37,4);r(9,24,9,35,6)
 r(47,21,51,39,1);r(48,23,50,37,4);r(48,24,48,35,6)
 poly({{51,12},{56,9},{59,10},{59,29},{54,29},{53,26},{55,25},{55,14},{52,16}},1)
 l(53,12,56,11,5);r(57,12,57,26,4);r(54,27,57,27,5)
 poly({{7,18},{49,18},{53,21},{52,24},{6,24},{4,22}},1)
 poly({{8,19},{48,19},{51,21},{6,21}},5);r(6,22,51,22,7);r(7,23,50,23,8)
 poly({{10,33},{48,33},{52,36},{50,39},{9,39},{6,36}},1)
 poly({{11,34},{47,34},{50,36},{9,36}},5);r(9,37,49,37,6);r(10,38,48,38,3)
 -- Swivel forks do not share one continuous "shadow shelf".
 r(11,38,14,42,4);r(46,38,49,42,4)
 if revision>=3 then caster(8);caster(46)else wheel(7,38);wheel(45,38)end
 I=s.material
 -- Tube rack at left, tall reagent bottle on the right.
 for x=10,26,8 do
   r(x,7,x+3,8,2);r(x,9,x+3,18,11);r(x+1,9,x+2,17,12);r(x+1,10,x+1,15,14)
 end
 r(8,16,31,18,3);r(8,16,31,16,5);r(9,19,31,20,2)
 bottle(37,5,14,12)
 -- Sample transport case and a secured bottle on the lower shelf.
 bevel(18,27,17,8,8);r(19,26,32,27,5);r(23,25,29,26,2);r(24,25,28,25,6)
 r(20,28,31,32,9);r(21,29,25,31,6)
 bottle(38,24,10,9)
 I=s.functionals;r(13,8,14,9,16);r(21,8,22,9,15)
 r(26,29,28,31,2);r(27,29,28,30,5)
 I=s.shadow;r(7,46,16,46,1);r(45,46,54,46,1)
end
local function fan(x,y)
 poly({{x+3,y},{x+8,y},{x+11,y+3},{x+11,y+8},{x+8,y+11},{x+3,y+11},{x,y+8},{x,y+3}},1)
 poly({{x+3,y+1},{x+7,y+1},{x+10,y+4},{x+10,y+7},{x+7,y+10},{x+3,y+10},{x+1,y+7},{x+1,y+3}},4)
 r(x+3,y+3,x+8,y+8,2);r(x+4,y+2,x+5,y+4,3);r(x+7,y+4,x+9,y+5,3)
 r(x+6,y+7,x+7,y+9,3);r(x+2,y+6,x+4,y+7,3);r(x+5,y+5,x+6,y+6,5)
end
local function rack(s)
 I=s.structure
 poly({{12,3},{50,3},{55,7},{55,81},{50,84},{9,84},{5,80},{5,9}},1)
 poly({{12,4},{49,4},{52,7},{15,9},{7,8}},5);l(15,8,51,7,6)
 poly({{6,10},{13,10},{13,80},{7,78}},3);r(8,12,10,76,4)
 r(14,10,53,79,2);r(16,12,51,77,1);r(14,11,15,78,4);r(51,11,52,77,4)
 r(15,11,15,29,5);r(15,44,15,65,5)
 -- Patch panel; main compute unit; twin drives; cooling block.
 bevel(18,13,31,12,3);r(20,16,46,22,2)
 bevel(18,27,31,17,4);r(20,30,37,39,1);r(22,32,35,37,11)
 r(39,30,46,39,3)
 bevel(18,46,31,7,4);bevel(18,55,31,7,4)
 bevel(18,64,31,14,3)
 fan(20,65);fan(35,65)
 r(10,80,52,82,3);r(12,80,50,80,5);r(10,83,17,85,2);r(45,83,53,85,2)
 -- Side cable chase, not disconnected floating marks.
 r(55,23,58,72,1);r(56,24,57,69,3);r(53,71,57,73,2)
 I=s.material;r(23,33,34,36,12);r(23,33,28,34,13)
 I=s.functionals
 for x=21,41,5 do r(x,17,x+2,19,1);r(x,17,x+2,17,9)end
 r(21,21,30,22,5);r(35,21,39,22,12);r(43,21,45,22,15)
 r(41,31,44,33,2);r(41,31,42,32,15);r(41,36,44,37,2)
 for _,y in ipairs({48,57})do r(21,y,39,y+2,2);r(23,y,36,y,5);r(43,y,45,y+1,13)end
 I=s.shadow;r(8,86,54,86,1)
end
local specs={{"microscope_station",55,59,microscope},{"sample_cart",63,48,cart},{"server_rack",61,88,rack}}
local function finish(name,s)
 I=s.finish
 if name=="microscope_station"then
  -- Front and back planes of the tilted optical head, not a flat icon.
  poly({{29,11},{32,14},{29,16},{25,16},{25,14},{29,14}},4)
  r(24,10,25,11,6);l(24,9,28,11,6);r(24,12,26,13,5)
  r(26,17,28,18,8);r(26,17,28,17,10);r(27,20,28,21,6)
  r(23,21,24,22,4);r(27,22,28,23,3)
  r(37,20,39,21,5);r(36,22,37,23,6);r(38,24,40,25,2)
  r(39,23,40,24,3);r(34,29,35,30,5)
  r(18,25,20,26,3);r(28,25,30,26,3);r(21,25,25,25,14)
  r(19,24,20,24,6);r(29,24,30,24,6)
  r(23,33,26,33,7);r(33,33,35,34,4)
  r(17,35,38,35,3);r(18,36,33,36,4)
  r(6,37,12,37,5);r(25,37,37,37,5);r(39,37,46,37,6)
  r(8,38,18,38,6);r(31,38,35,38,6);r(42,39,47,39,9)
  r(12,42,12,49,6);r(14,43,16,45,6);r(14,48,18,50,4)
  r(27,47,29,50,4);r(19,50,26,50,3);r(28,43,29,45,4)
  r(33,43,34,43,5);r(34,44,41,46,11);r(35,44,36,45,13);r(38,44,40,45,14)
  r(34,50,38,50,2);r(40,50,43,50,2)
  r(7,46,8,50,3);r(9,43,9,46,5);r(43,53,46,54,2)
  bolt(6,40);bolt(46,40)
  -- Visible cord connects instrument base to the side control.
  l(17,32,16,30,1);l(16,30,14,30,1);r(14,30,15,30,4)
  r(8,55,12,55,4);r(40,55,44,55,4)
 elseif name=="sample_cart"then
  -- Push-handle attachment collars bridge the gap visible in r1.
  r(50,21,57,24,1);r(51,22,56,23,4);r(52,22,54,22,6)
  r(49,29,56,31,1);r(50,29,55,30,4);r(50,29,52,29,5)
  r(55,12,57,14,4);r(56,12,57,12,6);r(57,16,57,21,5)
  r(56,26,57,28,3)
  -- Lower shelf contents cast short hard contact shadows, no glow.
  r(18,34,34,35,3);r(35,34,44,35,3)
  r(8,21,13,21,6);r(24,21,31,21,6);r(42,21,49,21,6)
  r(9,22,18,22,6);r(25,22,34,22,5);r(43,22,49,22,6)
  r(9,37,15,37,5);r(26,37,36,37,5);r(43,37,48,37,5)
  r(9,26,11,27,3);r(9,26,10,26,6);r(48,26,50,27,3);r(48,26,49,26,6)
  r(9,32,10,34,5);r(48,32,49,34,5)
  r(11,38,14,40,5);r(12,40,14,41,3);r(46,38,49,40,5);r(47,40,49,41,3)
  r(9,42,10,43,5);r(47,42,48,43,5);r(13,44,14,45,2);r(51,44,52,45,2)
  r(11,7,12,8,6);r(19,7,20,8,6);r(27,7,28,8,6)
  r(12,12,12,15,13);r(20,12,20,15,13);r(28,12,28,15,13)
  r(9,17,10,18,4);r(29,17,30,18,4);r(12,19,27,19,5)
  r(40,7,42,8,4);r(39,11,40,13,14);r(39,14,42,15,6);r(40,14,41,15,5)
  r(41,16,42,17,11);r(38,18,42,18,13)
  r(19,28,20,30,10);r(20,32,23,33,8);r(30,29,32,33,8)
  r(22,29,24,29,7);r(39,30,40,32,10)
  if revision>=3 then caster(8);caster(46)end
 elseif name=="server_rack"then
  -- Directional material clusters break the long continuous rail highlight.
  r(8,12,9,16,5);r(9,20,10,39,3);r(8,46,10,64,3);r(9,65,10,72,4)
  r(7,31,11,33,2);r(8,31,10,32,4);r(7,67,11,69,2);r(8,67,10,68,4)
  r(15,17,15,25,4);r(15,49,15,56,4);r(51,14,51,23,5)
  r(51,30,51,38,5);r(51,67,51,74,3)
  bolt(13,11);bolt(50,11);bolt(13,40);bolt(50,40);bolt(13,75);bolt(50,75)
  r(15,5,25,5,6);r(29,6,40,6,6);r(43,5,48,6,4)
  r(21,14,24,14,6);r(31,14,38,14,4);r(44,14,47,14,4)
  -- Two short patch leads; grouped ports remain legible at x2.
  r(22,18,23,19,10);r(27,18,28,19,10)
  l(23,20,23,23,8);l(23,23,28,23,8);l(28,23,28,20,8)
  r(23,21,23,22,9);r(27,23,28,23,9)
  r(40,21,41,22,2)
  r(19,29,20,36,5);r(21,28,28,28,5);r(43,28,47,28,3)
  r(23,33,34,37,11);r(23,33,27,34,13);r(29,33,33,35,12)
  r(24,36,27,36,12);r(29,36,30,37,13);r(32,35,34,37,14)
  r(39,32,40,36,4);r(43,38,46,39,2);r(21,41,27,42,3)
  r(30,41,36,42,2);r(30,41,34,41,5)
  r(19,47,21,48,5);r(38,50,40,51,3);r(24,51,35,51,3)
  r(19,56,21,57,5);r(38,59,40,60,3);r(24,60,35,60,3)
  r(43,57,45,58,8);r(43,57,44,57,15)
  r(23,65,26,65,5);r(38,65,41,65,5);r(20,71,20,73,3);r(45,72,45,74,2)
  r(55,26,58,28,2);r(56,26,57,27,5);r(55,54,58,56,2);r(56,54,57,55,5)
  r(56,32,56,49,12);r(56,59,56,66,12);r(54,71,56,72,3)
  r(12,81,21,81,4);r(39,81,49,81,4);r(11,84,15,84,4);r(46,84,51,84,4)
 end
end
for _,a in ipairs(specs)do
 local sprite=Sprite(a[2],a[3],ColorMode.RGB);sprite:deleteLayer(sprite.layers[1]);local images={};local layers={}
 for _,name in ipairs({"shadow","structure","material","functionals","finish"})do
  layers[name]=sprite:newLayer();layers[name].name=name;images[name]=Image(sprite.spec);images[name]:clear()
 end
 a[4](images)
 if revision>=2 then finish(a[1],images)end
 for name,img in pairs(images)do sprite:newCel(layers[name],sprite.frames[1],img,Point(0,0))end
 local pal=Palette(#hex);for i,c in ipairs(colors)do pal:setColor(i-1,Color{r=app.pixelColor.rgbaR(c),g=app.pixelColor.rgbaG(c),b=app.pixelColor.rgbaB(c),a=255})end
 sprite:setPalette(pal);sprite:saveAs(app.fs.joinPath(out,a[1]..".aseprite"));sprite:close()
end
