local s=assert(app.activeSprite,"No source sprite")
local expected=tonumber(app.params.layers)
assert(#s.layers==expected,"Incorrect editable layer count")
assert(#s.frames==1,"Study must contain one still frame")
local names={shadow=true,structure=true,material=true,functionals=true,finish=true}
for _,layer in ipairs(s.layers) do assert(names[layer.name],"Unexpected layer name") end
assert(s.colorMode==ColorMode.RGB,"Expected RGB source")
print("SOURCE PASS "..s.width.."x"..s.height.." layers="..#s.layers.." frames="..#s.frames)
