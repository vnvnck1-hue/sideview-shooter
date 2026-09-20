-- Native pixel studies. Do not publish from this script.
local out = assert(app.params.output_root, "output_root required")
local revision = tonumber(app.params.revision or "1")
assert(revision >= 1 and revision <= 3, "Unsupported revision")
local hex = {"171923","272938","3e414b","656264","8a8580","a8a293","c5c0ab",
             "634d43","96704a","b69863","17393e","255b60","438382","8fb5a4","dca64e","974e44"}
local C={}
for i,v in ipairs(hex) do C[i]=app.pixelColor.rgba(tonumber(v:sub(1,2),16),tonumber(v:sub(3,4),16),tonumber(v:sub(5,6),16),255) end
local I
local function p(x,y,c) if x>=0 and y>=0 and x<I.width and y<I.height then I:drawPixel(x,y,C[c]) end end
local function r(x,y,x1,y1,c) for yy=y,y1 do for xx=x,x1 do p(xx,yy,c) end end end
local function line(x,y,x1,y1,c)
  local dx,dy=math.abs(x1-x),-math.abs(y1-y); local sx,sy=x<x1 and 1 or -1,y<y1 and 1 or -1; local e=dx+dy
  while true do p(x,y,c);if x==x1 and y==y1 then break end;local e2=2*e
    if e2>=dy then e=e+dy;x=x+sx end;if e2<=dx then e=e+dx;y=y+sy end
  end
end
local function poly(v,c)
  local lo,hi=999,-999
  for _,a in ipairs(v) do lo=math.min(lo,a[2]);hi=math.max(hi,a[2]) end
  for y=lo,hi do
    local hits={};local scan=y+0.5
    for k,a in ipairs(v) do local b=v[k%#v+1]
      if (a[2]<=scan and b[2]>scan) or (b[2]<=scan and a[2]>scan) then
        hits[#hits+1]=a[1]+(scan-a[2])*(b[1]-a[1])/(b[2]-a[2])
      end
    end
    table.sort(hits);for k=1,#hits-1,2 do r(math.ceil(hits[k]),y,math.floor(hits[k+1]),y,c) end
  end
  for k,a in ipairs(v) do local b=v[k%#v+1];line(a[1],a[2],b[1],b[2],c) end
end
local function bolt(x,y) r(x,y,x+2,y+2,2);r(x,y,x+1,y,6);p(x+1,y+1,4) end
local function panel(x,y,w,h,base)
  r(x,y,x+w-1,y+h-1,2);r(x+1,y+1,x+w-2,y+h-2,base)
  r(x+1,y+1,x+w-3,y+1,6);r(x+w-2,y+2,x+w-2,y+h-2,3)
end
local function vent(x,y,w,n)
  r(x,y,x+w-1,y+n*3,3)
  for j=0,n-1 do r(x+1,y+1+j*3,x+w-2,y+2+j*3,1);r(x+2,y+3+j*3,x+w-3,y+3+j*3,4) end
end
local function bottle(x,y,h,c)
  r(x+1,y,x+4,y+1,6);r(x,y+2,x+5,y+h,11);r(x+1,y+3,x+4,y+h-1,c)
  r(x+1,y+3,x+1,y+h-2,14);r(x+2,y+h-3,x+4,y+h-2,12)
end
local function bench(s)
  I=s.structure
  -- Open leg bays and low shelf; asymmetric side plane matches workshop reference.
  poly({{8,28},{16,28},{16,49},{11,50},{7,47}},1);r(10,29,14,47,3);r(12,30,14,46,4)
  poly({{80,27},{89,27},{89,49},{84,50},{79,47}},1);r(83,29,87,47,3);r(85,30,87,46,4)
  poly({{13,42},{83,42},{86,45},{16,46}},1);poly({{15,42},{81,42},{83,44},{17,44}},4)
  r(17,45,81,46,2);r(17,45,80,45,8)
  poly({{9,29},{87,29},{88,32},{10,32}},2);r(13,30,83,31,4)
  panel(27,32,35,10,8);r(29,34,59,38,9);r(38,34,50,36,1);r(40,34,49,34,10)
  -- Broad top surface, thin lit front lip and deeper fascia, not a flat stripe.
  poly({{7,23},{87,23},{93,27},{93,31},{4,31},{2,28}},1)
  poly({{7,24},{86,24},{91,27},{5,27}},6);r(5,28,90,28,7)
  r(5,29,90,30,8);r(7,29,88,29,9);r(2,28,4,30,3)
  -- Raised analytical instrument, with dark left case and recessed display.
  poly({{9,5},{41,3},{46,6},{46,24},{9,24},{6,21},{6,9}},1)
  poly({{9,6},{41,4},{44,6},{12,8}},5);poly({{7,9},{11,8},{11,22},{8,21}},3)
  r(12,8,44,22,5);r(13,8,43,8,6);r(13,21,43,22,4)
  panel(15,10,24,11,3);r(17,12,36,18,11);r(18,13,34,17,12)
  r(20,20,31,21,2);r(22,20,29,20,4);r(13,23,44,24,2)
  -- Tube rack silhouette, larger than random indicator dots.
  r(54,22,85,24,2);r(57,19,82,22,4);r(55,21,84,22,6)
  I=s.material
  bottle(59,12,8,13);bottle(69,10,10,13);bottle(78,14,6,9)
  r(55,22,84,23,3);r(56,22,83,22,5)
  I=s.functionals
  r(18,14,25,15,13);r(28,14,33,16,14);r(40,11,42,13,15)
  bolt(9,29);bolt(86,29)
  I=s.shadow;r(8,50,18,51,1);r(80,50,91,51,1)
end
local function cold(s)
  I=s.structure
  poly({{11,3},{46,3},{51,7},{51,69},{45,72},{10,72},{5,67},{5,8}},1)
  poly({{11,4},{45,4},{49,7},{13,9},{7,8}},5);line(13,8,48,7,6)
  poly({{6,10},{12,10},{12,68},{7,66}},3);r(8,12,10,64,4)
  r(13,10,49,68,4);r(14,10,48,65,5);r(14,10,14,65,6)
  panel(16,14,31,24,5);panel(16,40,31,23,5)
  -- Door gaskets and metal shoulders around glass.
  r(19,17,39,34,2);r(20,18,38,33,11)
  r(19,43,39,59,2);r(20,44,38,58,11)
  r(42,22,45,31,2);r(42,23,43,29,7);r(44,23,44,30,4)
  r(42,48,45,56,2);r(42,49,43,54,7);r(44,49,44,55,4)
  r(13,67,49,69,2);r(15,67,46,67,4)
  r(11,70,18,73,1);r(43,70,50,73,1);r(12,70,17,71,3);r(44,70,48,71,3)
  I=s.material
  r(21,19,23,32,12);r(21,45,23,57,12)
  bottle(24,21,8,13);bottle(31,23,6,9);r(21,31,37,32,4);r(22,31,36,31,6)
  bottle(24,46,10,13);bottle(32,49,7,13);r(21,57,37,58,4);r(22,57,36,57,6)
  I=s.functionals
  r(19,10,32,12,2);r(21,11,27,12,13);r(35,11,38,12,15)
  vent(21,64,19,1)
  I=s.shadow;r(9,73,50,73,1)
end
local function chamber(s)
  I=s.structure
  -- Service tower and pipes behind glass, not an opaque rectangle.
  r(5,17,10,68,1);r(6,19,8,66,3);r(8,20,9,65,4)
  r(42,16,47,70,1);r(43,18,46,67,3);r(43,20,44,64,4)
  poly({{15,3},{35,3},{38,6},{38,11},{12,11},{12,6}},1)
  r(16,4,34,7,4);r(17,4,33,4,6);r(15,8,36,10,8)
  poly({{11,9},{39,9},{44,13},{44,18},{8,18},{8,13}},1)
  poly({{12,10},{38,10},{42,13},{10,13}},6);r(10,14,42,16,9);r(12,14,39,14,10)
  r(11,18,41,66,1);r(13,19,39,65,11)
  poly({{10,65},{40,65},{44,69},{44,77},{39,79},{9,79},{7,76},{7,69}},1)
  poly({{11,66},{39,66},{42,69},{9,69}},6);r(9,70,42,76,5);r(10,71,13,75,4)
  r(10,77,40,78,3);r(10,79,16,81,2);r(35,79,42,81,2)
  I=s.material
  r(14,20,16,63,12);r(17,19,19,64,13);r(20,19,34,64,12);r(35,20,37,62,13)
  r(38,22,39,61,11);r(18,21,18,60,14)
  -- Suspended biological sample: one readable mass and a branching stem.
  poly({{26,28},{29,29},{32,35},{31,43},{28,47},{28,54},{24,54},{24,46},{21,41},{22,33}},11)
  poly({{25,31},{28,31},{30,36},{28,40},{29,44},{26,49},{23,41},{23,35}},8)
  poly({{25,32},{27,33},{28,37},{26,40},{27,44},{25,44},{24,38}},9)
  r(25,48,27,60,8);r(26,49,27,60,9)
  r(22,60,31,62,3);r(23,60,30,60,6)
  I=s.functionals
  panel(18,70,16,6,3);r(20,72,27,73,12);r(21,72,25,72,14);r(30,72,32,74,15)
  bolt(10,70);bolt(38,70)
  I=s.shadow;r(8,82,43,82,1)
end
local specs={{"analysis_bench",96,53,bench},{"cold_storage",56,75,cold},{"specimen_chamber",52,84,chamber}}
local function refine(name,s)
  I=s.structure
  if name=="analysis_bench" then
    -- Structural information is added before surface accents.
    poly({{15,33},{25,33},{16,42},{14,42}},1)
    line(16,39,22,33,3);line(17,40,24,33,4)
    poly({{65,33},{79,43},{82,43},{69,33}},1)
    line(69,34,79,41,3);line(71,34,80,41,4)
    r(9,34,15,36,2);r(10,34,13,35,5);r(82,34,88,36,2);r(84,34,86,35,5)
    r(9,45,16,48,2);r(10,45,14,46,5);r(82,45,89,48,2);r(84,45,87,46,5)
    r(18,43,78,43,5);r(22,44,72,44,8)
    -- Drawer bevel narrows toward shadow; runners remain visibly separate.
    r(28,33,60,33,10);r(30,38,58,39,8);r(32,40,57,40,2)
    r(32,35,35,37,8);r(54,35,57,37,8)
    -- Instrument rim no longer has a continuous highlight on every edge.
    r(13,8,19,8,5);r(32,8,43,8,5);r(20,8,31,8,6)
    r(12,9,13,19,4);r(43,10,44,20,3);r(14,21,40,21,4)
    r(9,9,10,18,4);r(7,11,8,16,3)
    r(15,5,26,5,6);r(27,5,34,5,5);r(14,6,19,6,5)
    r(48,14,51,23,1);r(49,15,50,21,3);r(47,22,55,23,2)
    I=s.material
    -- Broad coherent material patches, not scattered noise.
    poly({{9,25},{28,25},{32,26},{8,26}},5)
    r(34,25,49,26,7);r(51,26,67,26,5);r(83,25,86,26,5)
    r(7,28,19,28,6);r(35,28,45,28,6);r(72,28,85,28,6)
    r(19,29,26,30,8);r(54,29,64,30,8)
    -- Rack lip and sleeves make a single assembled object.
    r(58,20,83,20,2);r(59,20,82,20,5);r(56,18,57,23,3);r(84,18,85,23,3)
    I=s.functionals
    r(18,13,35,17,11);line(18,16,21,16,13);line(21,16,23,13,13)
    line(23,13,25,16,13);line(25,16,29,16,13);r(31,13,34,15,14)
    r(40,16,42,18,2);r(40,16,41,17,5);r(36,22,40,23,2)
    r(37,22,39,22,6);r(17,22,23,23,3);r(18,22,21,22,5)
    bolt(9,29);bolt(86,29);bolt(10,34);bolt(84,34)
  elseif name=="cold_storage" then
    -- Break box symmetry with hardware, but preserve clean door centers.
    r(7,17,11,19,2);r(8,17,10,18,5);r(7,51,11,53,2);r(8,51,10,52,5)
    r(13,17,17,20,1);r(14,17,16,19,4);r(14,17,15,18,6)
    r(13,31,17,34,1);r(14,31,16,33,4);r(14,31,15,32,6)
    r(13,43,17,46,1);r(14,43,16,45,4);r(14,43,15,44,6)
    r(13,56,17,59,1);r(14,56,16,58,4);r(14,56,15,57,6)
    r(18,15,21,15,5);r(29,15,44,15,5);r(22,15,28,15,6)
    r(18,41,25,41,5);r(34,41,44,41,5);r(26,41,33,41,6)
    r(17,36,44,36,4);r(18,35,25,35,4);r(35,35,44,35,4)
    r(17,61,44,61,4);r(18,60,25,60,4);r(35,60,44,60,4)
    r(47,15,48,36,3);r(47,41,48,61,3)
    r(8,22,9,46,3);r(10,28,11,45,3)
    r(14,5,30,5,6);r(36,5,43,5,4);r(41,6,46,6,4)
    I=s.material
    -- Glass: dark interior, shelf thickness and a short broken reflection plane.
    r(36,19,37,23,14);r(35,22,36,27,13);r(36,28,37,29,12)
    r(36,45,37,49,14);r(35,48,36,53,13)
    r(21,20,22,27,13);r(21,46,22,53,13)
    r(24,28,28,29,11);r(24,29,28,29,13)
    r(25,50,28,52,14);r(26,51,28,52,12)
    I=s.functionals
    r(42,23,43,24,6);r(42,27,43,29,4);r(42,49,43,50,6);r(42,53,43,54,4)
    r(19,65,20,66,2);r(41,64,44,66,2);r(42,64,43,65,5)
    bolt(46,10);r(18,38,25,38,3);r(36,38,45,38,2)
  elseif name=="specimen_chamber" then
    -- Plumbing and segmented clamps give the vessel a designed silhouette.
    r(4,24,10,28,1);r(5,24,9,27,4);r(5,24,8,25,6)
    r(4,55,10,59,1);r(5,55,9,58,4);r(5,55,8,56,6)
    r(42,27,48,31,1);r(43,27,47,30,4);r(43,27,46,28,6)
    r(42,58,48,62,1);r(43,58,47,61,4);r(43,58,46,59,6)
    r(11,14,14,16,8);r(38,14,42,16,8);r(15,16,37,17,8)
    r(15,14,24,14,7);r(25,14,31,14,10);r(13,11,19,11,7)
    r(17,5,32,6,3);r(18,5,25,5,5);r(17,8,23,9,9);r(31,8,35,9,3)
    r(14,67,35,68,10);r(11,68,15,69,8);r(37,68,41,69,8)
    r(36,71,40,76,4);r(9,75,14,76,3);r(14,77,35,77,4)
    r(8,71,8,75,3);r(43,71,43,75,3)
    I=s.material
    -- A cylinder has changing plane widths, not one long neon stripe.
    r(17,19,19,64,12);r(17,23,18,56,13);r(18,25,18,52,14)
    r(19,21,20,28,13);r(19,54,20,61,13)
    r(35,20,37,62,12);r(36,22,37,31,14);r(35,29,36,36,13)
    r(36,46,37,58,13);r(37,38,38,48,11)
    -- Support tube and multi-lobed tissue occupy the center at medium scale.
    line(24,20,24,29,3);r(23,21,25,23,4);r(24,24,25,28,3)
    poly({{25,29},{28,29},{31,33},{30,37},{32,40},{29,46},{28,49},{24,47},{23,43},{21,40},{22,33}},8)
    poly({{24,32},{26,31},{29,34},{27,37},{29,40},{27,44},{25,44},{24,40},{23,37}},9)
    r(24,32,26,33,10);r(27,39,28,40,10);r(24,42,25,43,16)
    r(30,35,31,37,11);r(28,45,29,47,11);r(24,45,25,49,8)
    line(28,48,31,51,8);line(31,51,30,55,8);line(26,50,23,54,9)
    r(24,55,26,59,9);r(24,59,30,60,8)
    r(21,62,32,63,2);r(22,62,31,62,4);r(22,60,23,61,5);r(30,60,31,61,5)
    I=s.functionals
    r(20,73,27,74,11);r(21,73,24,73,13);r(25,72,27,73,14)
    r(30,72,32,73,15);r(30,74,32,74,8)
    bolt(10,70);bolt(38,70)
    -- Calibration ticks are clustered along one rim, never distributed as noise.
    r(14,29,15,30,13);r(14,37,15,38,13);r(14,45,15,46,13)
  end
end
local function finish(name,s)
  I=s.finish
  if name=="analysis_bench" then
    -- Local patches follow top wear, cast shadows and contact points.
    r(13,24,45,24,3);r(14,25,41,25,4);r(17,26,25,26,5)
    r(30,26,40,26,5);r(52,24,85,24,3)
    r(8,27,18,27,6);r(34,27,51,27,6);r(67,27,82,27,6)
    r(12,29,17,29,10);r(30,29,34,29,10);r(68,29,77,29,10)
    r(16,30,22,30,8);r(71,30,79,30,8)
    r(12,38,13,42,5);r(14,39,14,43,3);r(85,38,86,41,5)
    r(29,34,31,36,10);r(30,37,33,38,9);r(57,38,59,39,8)
    r(20,44,27,44,4);r(53,44,64,44,4)
    r(13,10,14,15,6);r(13,16,14,19,5);r(39,9,41,10,4)
    r(39,19,43,20,3);r(14,19,15,20,4)
    r(9,11,10,12,2);r(9,14,10,15,2);r(9,17,10,18,2)
    r(29,6,37,6,6);r(20,6,26,6,4)
    r(40,14,42,14,8);r(41,15,42,15,3)
    r(59,14,60,15,14);r(70,13,71,15,14);r(79,17,80,18,10)
    -- One cable bundle is attached at both ends instead of floating marks.
    line(47,18,52,18,1);line(52,18,52,22,1);r(50,22,54,23,2)
    line(48,18,51,18,4);r(52,20,52,21,4)
  elseif name=="cold_storage" then
    -- Soften redundant box outlines while keeping the true gasket dark.
    r(17,15,17,16,5);r(17,21,17,30,4);r(17,35,17,36,4)
    r(17,41,17,42,5);r(17,47,17,55,4);r(17,60,17,61,4)
    r(18,16,23,16,6);r(28,16,34,16,5);r(18,42,24,42,6)
    r(41,17,44,18,6);r(41,19,43,20,5);r(41,43,44,45,6)
    r(41,32,44,34,4);r(42,31,44,32,4);r(41,57,44,59,4)
    r(18,34,20,35,4);r(18,59,20,60,4)
    r(20,18,31,18,3);r(20,44,31,44,3)
    r(23,33,34,33,2);r(25,58,34,58,2)
    r(21,28,22,30,12);r(21,54,22,56,12)
    r(35,19,37,20,14);r(34,20,35,22,13);r(34,45,37,46,14)
    r(34,47,35,48,13);r(25,24,27,26,14);r(26,25,28,26,12)
    r(31,25,34,26,10);r(33,52,35,54,13)
    r(8,10,10,15,4);r(8,11,8,14,5);r(8,59,10,63,3)
    r(13,64,16,65,3);r(46,63,48,65,3)
    r(15,7,22,7,7);r(30,7,36,7,6);r(44,8,48,8,4)
    r(15,69,21,69,3);r(40,69,46,69,3)
  elseif name=="specimen_chamber" then
    -- Cropped specular clusters explain cylindrical volume at x6.
    poly({{20,20},{32,20},{32,23},{28,22},{22,23},{20,26}},11)
    poly({{20,59},{22,57},{22,61},{33,61},{34,58},{35,63},{20,64}},11)
    r(19,27,20,38,13);r(19,32,19,41,14);r(19,42,20,49,13)
    r(35,21,36,23,14);r(34,23,35,27,13);r(35,28,35,32,13)
    r(35,48,36,51,13);r(34,52,35,56,13);r(35,59,36,61,12)
    -- Glints are broad groups, not a uniformly luminous frame.
    r(18,25,18,31,13);r(18,44,18,49,13)
    r(22,35,23,37,9);r(24,34,25,35,10);r(26,35,28,36,8)
    r(22,38,24,40,8);r(23,41,24,42,9);r(28,41,29,43,8)
    r(26,45,27,47,16);r(26,45,26,46,9);r(24,46,25,47,8)
    line(23,49,21,52,8);line(21,52,22,56,8);r(22,55,23,57,9)
    line(29,53,32,55,8);r(31,55,32,57,9)
    r(25,25,26,28,4);r(25,26,25,28,5)
    -- Back pipe, elbow and cap. Every small part has a mechanical attachment.
    r(38,5,43,6,1);r(42,6,45,11,1);r(39,5,42,5,4);r(43,7,44,10,4)
    r(42,10,46,12,2);r(43,10,45,11,5)
    r(18,4,27,4,6);r(16,7,20,7,4);r(32,6,34,7,2)
    r(10,13,13,14,8);r(14,12,17,13,10);r(18,11,29,12,7)
    r(30,12,37,13,6);r(34,14,39,15,9);r(14,16,20,16,9)
    r(9,70,14,70,9);r(15,68,20,68,7);r(26,68,33,68,6)
    r(15,72,16,75,2);r(35,72,36,75,2);r(37,74,39,75,3)
    r(10,74,12,75,3);r(10,74,11,74,5)
    r(11,79,15,80,3);r(36,79,40,80,3)
  end
end
for _,a in ipairs(specs) do
  local sprite=Sprite(a[2],a[3],ColorMode.RGB);sprite:deleteLayer(sprite.layers[1])
  local imgs={};local layers={}
  local names={"shadow","structure","material","functionals"}
  if revision>=3 then names[#names+1]="finish" end
  for _,name in ipairs(names) do
    local layer=sprite:newLayer();layer.name=name;layers[name]=layer
    imgs[name]=Image(sprite.spec);imgs[name]:clear()
  end
  a[4](imgs)
  if revision>=2 then refine(a[1],imgs) end
  if revision>=3 then finish(a[1],imgs) end
  for name,img in pairs(imgs) do sprite:newCel(layers[name],sprite.frames[1],img,Point(0,0)) end
  local palette=Palette(#hex);for i=1,#hex do palette:setColor(i-1,Color{r=app.pixelColor.rgbaR(C[i]),g=app.pixelColor.rgbaG(C[i]),b=app.pixelColor.rgbaB(C[i]),a=255}) end
  sprite:setPalette(palette)
  sprite:saveAs(app.fs.joinPath(out,a[1]..".aseprite"));sprite:close()
end
