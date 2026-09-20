-- Geometry-first rebuild. Native pixels; no resampling, noise or free bevel patches.
local out=assert(app.params.output_root)
local hex={"171923","272938","3e414b","656264","8a8580","a8a293","c5c0ab","634d43","96704a","b69863","17393e","255b60","438382","8fb5a4","dca64e","974e44"}
local C={};for i,h in ipairs(hex)do C[i]=app.pixelColor.rgba(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16),255)end
local I
local function p(x,y,c)
 assert(x%1==0 and y%1==0 and x>0 and y>0 and x<I.width-1 and y<I.height-1,"Invalid native coordinate")
 I:drawPixel(x,y,C[c])
end
local function r(x,y,x2,y2,c)assert(x<=x2 and y<=y2);for yy=y,y2 do for xx=x,x2 do p(xx,yy,c)end end end
local function stamp(x,y,rows,colors)
 for dy,row in ipairs(rows)do for dx=1,#row do local key=row:sub(dx,dx);if key~="."then p(x+dx-1,y+dy-1,colors[key])end end end
end
-- Every cabinet/tray uses the same leftward/upward depth vector (-4,-2).
local function box(x,y,w,h,front)
 r(x,y,x+w-1,y+h-1,1)
 r(x+1,y+1,x+w-2,y+h-2,front)
 r(x-4,y-2,x+w-5,y-2,1);r(x-3,y-1,x+w-3,y-1,5)
 r(x-4,y-1,x-4,y+h-3,1);r(x-3,y,x-1,y+h-3,3)
 p(x-3,y+h-2,1);p(x-2,y+h-2,1);p(x-1,y+h-1,1)
end
local function disc(x,y)
 stamp(x,y,{"..###..",".#aaa#.","#abbaa#","#abcca#","#aacca#",".#aaa#.","..###.."},{["#"]=1,a=3,b=5,c=2})
end
local function bottle(x,y,h)
 r(x+2,y,x+6,y+1,2);r(x+3,y+2,x+5,y+3,11)
 r(x+1,y+4,x+7,y+h-1,11);r(x+2,y+4,x+6,y+h-2,12)
 r(x+2,y+5,x+3,y+h-3,13);r(x+4,y+5,x+5,y+7,11)
 r(x+2,y+h-5,x+6,y+h-4,6)
end
local function microscope(s)
 I=s.structure
 -- Fixed rectangular desk, 44x17 front, left-plane depth 4x2.
 box(8,39,44,17,4);r(8,39,51,41,8)
 r(10,56,16,57,1);r(43,56,49,57,1)
 box(7,37,46,4,9)
 -- Continuous C support. Head and focus control attach to this same arm.
 r(33,13,39,31,1);r(34,14,38,30,4);r(34,14,35,29,6)
 r(23,11,38,16,1);r(24,12,37,15,5);r(25,12,36,12,6)
 -- Single eyepiece uses exact 1:1 stairs and constant normal thickness.
 stamp(15,2,{".####......","#aaab#.....","#accab#....",".#accab#...","..#accab#..","...#accab#.","....#aaab#.",".....####.."},{["#"]=1,a=4,b=3,c=6})
 r(21,9,29,17,1);r(22,10,28,16,5);r(22,10,24,15,6);r(27,11,28,16,4)
 -- Objective axis x25, sample centre x25. Open gap y23..24.
 r(22,17,28,19,2);r(23,18,27,20,9);r(24,20,26,22,5)
 r(24,22,26,22,1)
 box(17,27,18,3,3);r(18,27,33,27,5)
 r(24,30,28,32,1);r(25,30,27,31,6)
 box(20,34,23,3,4);r(21,34,40,34,6)
 disc(35,18)
 -- Desk drawer and separate controls, aligned inside the front frame.
 r(11,44,31,53,2);r(12,45,30,52,5)
 r(34,44,48,53,2);r(35,45,47,52,3)
 I=s.material
 r(12,45,30,46,6);r(12,51,30,52,4)
 r(35,45,47,45,4);r(9,42,50,42,3)
 r(9,40,50,40,10);r(5,38,6,39,8)
 r(22,35,38,35,5);r(34,28,35,30,5)
 I=s.functionals
 r(18,46,25,48,2);r(19,46,24,46,4)
 r(37,46,45,48,11);r(38,46,41,47,13);r(43,46,44,47,12)
 r(37,50,39,51,4);r(44,50,45,51,15)
 r(22,26,28,27,12);r(23,26,26,26,14)
 I=s.finish
 r(12,49,14,50,6);r(28,48,29,50,4)
 r(46,38,50,38,10);r(23,13,24,14,7)
 I=s.shadow;r(10,57,16,57,1);r(43,57,49,57,1)
end
local function cart(s)
 I=s.structure
 -- Two copies of exactly the same tray and vertical post dimensions.
 for _,x in ipairs({10,48})do r(x,19,x+3,39,1);r(x+1,20,x+2,38,4)end
 -- Rectilinear push handle: one continuous tube, two attachment sockets.
 r(51,9,58,11,1);r(56,10,58,34,1)
 r(52,10,57,10,5);r(57,11,57,33,4)
 r(50,20,58,22,1);r(51,21,57,21,4)
 r(50,33,58,35,1);r(51,34,57,34,4)
 box(8,20,45,4,4);box(8,36,45,4,4)
 for _,x in ipairs({10,48})do
  r(x,39,x+3,42,1);r(x+1,39,x+2,42,5);disc(x-1,40)
 end
 -- Tube rack: repeated identical profiles, spaced on the same 8px pitch.
 for _,x in ipairs({10,18,26})do
  r(x,6,x+4,8,2);r(x,9,x+4,18,11);r(x+1,9,x+3,17,12)
  r(x+1,9,x+1,16,13);r(x+1,7,x+3,7,5)
 end
 r(9,16,31,18,3);r(9,16,31,16,5);r(10,19,30,19,2)
 bottle(38,4,15)
 -- Lower cargo fits between posts, rests on shelf, not on its front lip.
 r(20,25,27,26,2);r(21,25,26,25,5)
 r(17,27,33,34,1);r(18,28,32,33,9);r(18,28,32,28,10)
 r(36,28,43,34,1);r(37,29,42,33,8)
 I=s.material
 for _,y in ipairs({20,36})do r(9,y+1,51,y+1,5);r(9,y+2,51,y+2,3)end
 r(18,32,32,33,8);r(31,29,32,31,8)
 I=s.functionals
 r(20,29,24,31,6);r(28,29,30,31,2);r(29,29,30,30,5)
 r(38,30,41,31,10);r(19,7,21,8,16)
 I=s.finish
 r(40,9,41,11,14);r(11,11,11,13,14);r(27,11,27,13,14)
 -- Light does not interrupt either tray outline or post silhouette.
 r(11,25,11,28,5);r(49,25,49,28,5)
 I=s.shadow;r(11,46,13,46,1);r(49,46,51,46,1)
end
local function rack(s)
 I=s.structure
 -- All chassis edges stay horizontal/vertical. Depth is not a chamfer.
 box(10,6,46,78,4)
 r(12,9,53,80,1);r(13,10,15,79,3);r(50,10,52,79,3)
 r(10,84,17,86,1);r(48,84,55,86,1)
 -- A shared 32px module width and 2px vertical gaps.
 local modules={{12,12},{26,17},{45,7},{54,7},{63,15}}
 for _,m in ipairs(modules)do
  local y,h=m[1],m[2];r(17,y,48,y+h-1,2);r(18,y+1,47,y+h-2,4)
 end
 r(20,29,37,38,1);r(21,30,36,37,11)
 -- Paired fans share an identical pixel mask; true centres are on one row.
 for _,x in ipairs({20,35})do
  stamp(x,65,{"...#####...","..#aaaaa#..",".#aabbbba#.","#aabbcbbaa#","#abbcccbba#","#abcdddcba#","#abbcccbba#","#aabbcbbaa#",".#aabbbba#.","..#aaaaa#..","...#####..."},{["#"]=1,a=3,b=2,c=4,d=5})
 end
 I=s.material
 r(11,7,54,7,5);r(7,9,8,80,3)
 for _,m in ipairs(modules)do local y,h=m[1],m[2]
  r(18,y+1,47,y+1,5);r(18,y+h-2,47,y+h-2,3)
 end
 r(22,31,35,36,12);r(22,31,28,32,13)
 I=s.functionals
 for _,x in ipairs({20,27,34,41})do r(x,16,x+4,19,1);r(x+1,16,x+3,17,9)end
 r(21,21,29,22,5);r(41,21,43,22,15)
 r(40,30,44,33,2);r(41,30,42,31,15)
 r(40,36,45,37,2);r(21,40,36,41,2)
 r(24,34,29,35,11);r(31,33,34,35,14)
 for _,y in ipairs({47,56})do
  r(20,y,38,y+2,2);r(22,y,35,y,5);r(43,y,45,y+1,13)
 end
 -- Rail fasteners repeated at the same x positions, entirely inside rails.
 for _,y in ipairs({12,40,75})do r(13,y,14,y+1,5);r(51,y,52,y+1,5)end
 I=s.finish
 r(20,14,24,14,6);r(18,28,19,31,5)
 r(7,15,8,23,4);r(7,58,8,65,4)
 r(11,81,54,82,3);r(12,85,15,85,4);r(50,85,53,85,4)
 I=s.shadow;r(11,86,16,86,1);r(49,86,54,86,1)
end
local specs={{"microscope_station",55,59,microscope},{"sample_cart",63,48,cart},{"server_rack",61,88,rack}}
local function palette(sprite)
 local pal=Palette(#hex);for i,c in ipairs(C)do pal:setColor(i-1,Color{r=app.pixelColor.rgbaR(c),g=app.pixelColor.rgbaG(c),b=app.pixelColor.rgbaB(c),a=255})end;sprite:setPalette(pal)
end
for _,a in ipairs(specs)do
 local sprite=Sprite(a[2],a[3],ColorMode.RGB);sprite:deleteLayer(sprite.layers[1]);local s={};local layers={}
 for _,name in ipairs({"shadow","structure","material","functionals","finish"})do
  layers[name]=sprite:newLayer();layers[name].name=name;s[name]=Image(sprite.spec);s[name]:clear()
 end
 a[4](s)
 -- Later passes may change colour only: they cannot introduce a bump into the silhouette.
 for _,name in ipairs({"material","functionals","finish"})do
  for y=0,a[3]-1 do for x=0,a[2]-1 do
   if app.pixelColor.rgbaA(s[name]:getPixel(x,y))>0 then
    assert(app.pixelColor.rgbaA(s.structure:getPixel(x,y))>0,a[1].." detail outside locked structure at "..x..","..y)
   end
  end end
 end
 for name,img in pairs(s)do sprite:newCel(layers[name],sprite.frames[1],img,Point(0,0))end
 palette(sprite);sprite:saveAs(app.fs.joinPath(out,a[1]..".aseprite"))
 local flat=Sprite(a[2],a[3],ColorMode.RGB);flat.layers[1].name="structure"
 flat:newCel(flat.layers[1],flat.frames[1],s.structure,Point(0,0));palette(flat)
 flat:saveAs(app.fs.joinPath(out,a[1].."-structure.aseprite"));flat:close();sprite:close()
 print("GEOMETRY MASK PASS: "..a[1])
end
