local outputRoot = app.params["output_root"]
if outputRoot == nil or outputRoot == "" then
  error("Missing --script-param output_root=<absolute directory>")
end

local function rgba(hex)
  local value = hex:gsub("#", "")
  return app.pixelColor.rgba(
    tonumber(value:sub(1, 2), 16),
    tonumber(value:sub(3, 4), 16),
    tonumber(value:sub(5, 6), 16),
    255)
end

local transparent = app.pixelColor.rgba(0, 0, 0, 0)
local themes = {
  research_analysis = {
    deep="#253b4b", line="#526d79", shade="#667e89", wall="#879da6",
    panel="#99adb4", light="#d6ded9", warm="#c8c9bd", floor="#b7c4c2",
    accent="#54d8bd", glass="#83bbb9", screen="#287a7c",
  },
  research_isolation = {
    deep="#293f4c", line="#5e747e", shade="#748992", wall="#94a5ad",
    panel="#aab9bd", light="#e0e4df", warm="#d0d3ca", floor="#c4d0cc",
    accent="#55d8ed", glass="#91cbd2", screen="#338aa0",
  },
  research_diagnostics = {
    deep="#1f3447", line="#4c6573", shade="#617886", wall="#81939f",
    panel="#96a8b2", light="#d1d9d8", warm="#c8cac2", floor="#acbdc2",
    accent="#5ab9ff", glass="#79aabd", screen="#245f84",
  },
}

local specs = {
  {theme="research_analysis", name="specimen_chamber", w=52, h=84},
  {theme="research_analysis", name="analysis_bench", w=96, h=53},
  {theme="research_analysis", name="microscope_station", w=55, h=59},
  {theme="research_analysis", name="cold_storage", w=56, h=75},
  {theme="research_analysis", name="sample_cart", w=63, h=48},
  {theme="research_isolation", name="decon_arch", w=79, h=102},
  {theme="research_isolation", name="isolation_pod", w=102, h=62},
  {theme="research_isolation", name="wash_station", w=65, h=59},
  {theme="research_isolation", name="medical_cabinet", w=54, h=79},
  {theme="research_isolation", name="uv_sterilizer", w=54, h=68},
  {theme="research_diagnostics", name="diagnostic_console", w=94, h=62},
  {theme="research_diagnostics", name="server_rack", w=61, h=88},
  {theme="research_diagnostics", name="wall_display", w=100, h=53},
  {theme="research_diagnostics", name="signal_scope", w=58, h=65},
  {theme="research_diagnostics", name="drone_dock", w=80, h=55},
}

local function colorize(p)
  local result = {}
  for key, value in pairs(p) do result[key] = rgba(value) end
  return result
end

local function rect(image, x0, y0, x1, y1, color)
  x0 = math.max(0, x0); y0 = math.max(0, y0)
  x1 = math.min(image.width - 1, x1); y1 = math.min(image.height - 1, y1)
  for y = y0, y1 do
    for x = x0, x1 do image:drawPixel(x, y, color) end
  end
end

local function pixel(image, x, y, color)
  if x >= 0 and y >= 0 and x < image.width and y < image.height then
    image:drawPixel(x, y, color)
  end
end

local function line(image, x0, y0, x1, y1, color)
  local dx = math.abs(x1 - x0)
  local sx = x0 < x1 and 1 or -1
  local dy = -math.abs(y1 - y0)
  local sy = y0 < y1 and 1 or -1
  local err = dx + dy
  while true do
    pixel(image, x0, y0, color)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x0 = x0 + sx end
    if e2 <= dx then err = err + dx; y0 = y0 + sy end
  end
end

local function steppedBody(image, p, x0, y0, x1, y1, side)
  side = side or 4
  rect(image, x0 + 2, y0, x1 - 2, y0 + 1, p.deep)
  rect(image, x0 + 1, y0 + 2, x1 - 1, y1 - 1, p.deep)
  rect(image, x0, y0 + 4, x1, y1 - 3, p.deep)
  rect(image, x0 + 2, y0 + 2, x1 - side, y1 - 2, p.warm)
  rect(image, x0 + 3, y0 + 2, x1 - side - 1, y0 + 3, p.light)
  rect(image, x0 + 2, y0 + 4, x0 + 3, y1 - 3, p.panel)
  rect(image, x1 - side + 1, y0 + 2, x1 - 2, y1 - 2, p.shade)
  rect(image, x0 + 3, y1 - 3, x1 - side - 1, y1 - 2, p.line)
end

local function screen(image, p, x0, y0, x1, y1)
  rect(image, x0, y0, x1, y1, p.deep)
  rect(image, x0 + 2, y0 + 2, x1 - 2, y1 - 2, p.screen)
  rect(image, x0 + 3, y0 + 3, x1 - 3, y0 + 4, p.accent)
  rect(image, x0 + 3, y1 - 3, x0 + 6, y1 - 2, p.glass)
end

local function glass(image, p, x0, y0, x1, y1)
  rect(image, x0, y0, x1, y1, p.line)
  rect(image, x0 + 2, y0 + 2, x1 - 2, y1 - 2, p.glass)
  rect(image, x0 + 3, y0 + 3, x0 + 4, y1 - 4, p.light)
  rect(image, x1 - 4, y0 + 4, x1 - 3, y1 - 3, p.shade)
end

local function bolt(image, p, x, y)
  pixel(image, x, y, p.deep)
  pixel(image, x + 1, y, p.light)
end

local function vent(image, p, x, y, width, rows)
  rect(image, x, y, x + width - 1, y + rows * 2, p.deep)
  for row = 0, rows - 1 do
    rect(image, x + 2, y + 1 + row * 2, x + width - 3, y + 1 + row * 2, p.shade)
  end
end

local function wheel(image, p, x, y)
  rect(image, x + 1, y, x + 4, y + 5, p.deep)
  rect(image, x, y + 1, x + 5, y + 4, p.deep)
  rect(image, x + 2, y + 2, x + 3, y + 3, p.line)
end

local function feetAndShadow(images, p, w, h, left, right)
  rect(images.shadow, left - 2, h - 3, right + 2, h - 2, p.deep)
  rect(images.structure, left, h - 5, left + 5, h - 2, p.deep)
  rect(images.structure, right - 5, h - 5, right, h - 2, p.deep)
  rect(images.details, left + 1, h - 4, left + 4, h - 3, p.line)
  rect(images.details, right - 4, h - 4, right - 1, h - 3, p.line)
end

local function drawProp(name, images, p, w, h)
  local s, g, d = images.structure, images.glass, images.details
  if name == "specimen_chamber" then
    steppedBody(s, p, 5, 3, w - 6, h - 4, 5)
    rect(s, 10, 8, w - 11, 13, p.deep); rect(s, 16, 2, w - 17, 7, p.deep)
    glass(g, p, 11, 15, w - 15, h - 20)
    rect(g, 18, 27, w - 23, 53, p.screen); rect(g, 20, 30, w - 25, 50, p.accent)
    line(d, 21, 50, 24, 37, p.deep); line(d, 24, 37, 28, 45, p.deep)
    line(d, 25, 44, 20, 55, p.deep); line(d, 26, 45, 31, 56, p.deep)
    rect(d, 13, h - 16, w - 17, h - 14, p.accent)
    bolt(d, p, 9, 10); bolt(d, p, w - 12, 10)
    feetAndShadow(images, p, w, h, 8, w - 9)
  elseif name == "analysis_bench" then
    steppedBody(s, p, 2, 24, w - 3, 36, 6)
    rect(s, 7, 36, 18, h - 3, p.deep); rect(s, w - 19, 36, w - 8, h - 3, p.deep)
    rect(s, 9, 37, 16, h - 5, p.warm); rect(s, w - 17, 37, w - 10, h - 5, p.warm)
    steppedBody(s, p, 10, 5, 50, 24, 4)
    screen(g, p, 16, 8, 44, 21); glass(g, p, 57, 16, 78, 23)
    rect(d, 60, 10, 66, 15, p.glass); rect(d, 69, 12, 75, 15, p.accent)
    rect(d, 27, 38, 47, 41, p.deep); rect(d, 30, 39, 44, 40, p.warm)
    rect(d, 10, 42, 15, 43, p.line); rect(d, w - 16, 42, w - 11, 43, p.line)
    rect(d, 9, 46, 16, 47, p.line); rect(d, w - 17, 46, w - 10, 47, p.line)
    rect(d, 53, 27, 84, 29, p.deep); rect(d, 57, 25, 61, 27, p.glass)
    rect(d, 64, 23, 68, 27, p.accent); rect(d, 72, 24, 78, 27, p.light)
    bolt(d, p, 5, 29); bolt(d, p, w - 9, 29)
    feetAndShadow(images, p, w, h, 7, w - 8)
  elseif name == "microscope_station" then
    steppedBody(s, p, 7, 34, w - 8, h - 3, 4)
    rect(s, 17, 7, 38, 12, p.deep); rect(s, 20, 9, 34, 11, p.light)
    rect(s, 22, 11, 31, 27, p.shade); rect(s, 28, 23, 43, 28, p.deep)
    rect(s, 39, 27, 46, 35, p.line); rect(s, 16, 30, 46, 34, p.light)
    screen(g, p, 31, 36, 46, 47)
    rect(d, 11, 42, 24, 44, p.accent); rect(d, 20, 28, 26, 31, p.deep)
    pixel(d, 34, 16, p.accent); bolt(d, p, 11, 38)
    feetAndShadow(images, p, w, h, 9, w - 10)
  elseif name == "cold_storage" then
    steppedBody(s, p, 5, 2, w - 6, h - 3, 5)
    rect(s, 10, 10, w - 15, 36, p.light); rect(s, 10, 39, w - 15, h - 11, p.light)
    glass(g, p, 12, 12, w - 17, 34); glass(g, p, 12, 41, w - 17, h - 13)
    rect(d, 15, 23, w - 20, 24, p.line); rect(d, 15, 52, w - 20, 53, p.line)
    rect(d, 17, 17, 21, 22, p.accent); rect(d, 24, 18, 29, 22, p.warm)
    rect(d, 18, 45, 23, 51, p.light); rect(d, 27, 47, 32, 51, p.accent)
    rect(d, 10, 37, w - 15, 39, p.line); rect(d, 34, 20, 37, 29, p.shade)
    rect(d, 34, 50, 37, 59, p.shade); rect(d, 15, 12, 27, 14, p.accent)
    for y = 18, 56, 15 do bolt(d, p, 13, y) end
    feetAndShadow(images, p, w, h, 8, w - 9)
  elseif name == "sample_cart" then
    steppedBody(s, p, 5, 14, w - 6, 25, 4); steppedBody(s, p, 8, 30, w - 9, 38, 4)
    rect(s, 11, 24, 14, h - 8, p.line); rect(s, w - 16, 24, w - 13, h - 8, p.line)
    glass(g, p, 11, 4, 19, 13); rect(g, 24, 6, 34, 13, p.accent)
    rect(d, 38, 8, 52, 13, p.warm); rect(d, 40, 9, 50, 10, p.light)
    rect(d, 18, 32, 45, 34, p.deep); rect(d, w - 7, 10, w - 2, 13, p.deep)
    rect(d, 19, 28, 24, 31, p.glass); rect(d, 28, 27, 34, 31, p.accent)
    rect(d, 38, 28, 44, 31, p.warm); vent(d, p, 47, 29, 7, 2)
    wheel(d, p, 11, h - 7); wheel(d, p, w - 18, h - 7)
    feetAndShadow(images, p, w, h, 12, w - 13)
  elseif name == "decon_arch" then
    rect(s, 5, 11, 18, h - 5, p.deep); rect(s, w - 19, 11, w - 6, h - 5, p.deep)
    rect(s, 12, 3, w - 13, 18, p.deep); rect(s, 8, 7, w - 9, 14, p.warm)
    rect(s, 10, 8, w - 11, 10, p.light); rect(s, 8, h - 14, w - 9, h - 3, p.deep)
    rect(s, 13, h - 13, w - 14, h - 9, p.floor)
    rect(g, 11, 24, 16, 75, p.accent); rect(g, w - 17, 24, w - 12, 75, p.accent)
    rect(g, 29, 20, 32, 63, p.accent); rect(g, w - 33, 20, w - 30, 63, p.accent)
    rect(d, 23, 14, w - 24, 18, p.accent); bolt(d, p, 12, 13); bolt(d, p, w - 15, 13)
    rect(d, 18, 20, 21, 72, p.shade); rect(d, w - 22, 20, w - 19, 72, p.light)
    rect(d, 7, 79, 17, 82, p.line); rect(d, w - 18, 79, w - 8, 82, p.line)
    for x = 17, w - 18, 8 do rect(d, x, h - 11, x + 2, h - 5, p.light) end
    rect(images.shadow, 7, h - 3, w - 8, h - 2, p.deep)
  elseif name == "isolation_pod" then
    steppedBody(s, p, 3, 27, w - 4, h - 4, 6)
    rect(s, 8, 20, 18, 30, p.deep); rect(s, w - 19, 20, w - 9, 30, p.deep)
    glass(g, p, 10, 9, w - 12, 35)
    rect(g, 17, 13, 29, 31, p.light); rect(g, 31, 15, 71, 29, p.glass)
    rect(g, 22, 27, 76, 31, p.screen); rect(g, 26, 24, 37, 28, p.light)
    line(d, 34, 29, 45, 25, p.line); line(d, 45, 25, 56, 29, p.line)
    line(d, 57, 29, 65, 24, p.shade); rect(d, 20, 17, 23, 22, p.accent)
    rect(d, 75, 15, 88, 26, p.accent); rect(d, 78, 18, 85, 23, p.screen)
    rect(d, 12, h - 11, w - 13, h - 9, p.shade); vent(d, p, 42, h - 8, 18, 2)
    feetAndShadow(images, p, w, h, 7, w - 8)
  elseif name == "wash_station" then
    steppedBody(s, p, 6, 29, w - 7, h - 3, 4)
    rect(s, 10, 18, w - 11, 31, p.light); rect(s, 14, 21, w - 15, 28, p.panel)
    glass(g, p, 17, 23, w - 18, 29)
    rect(d, 30, 6, 33, 20, p.line); rect(d, 31, 6, 46, 9, p.line); rect(d, 44, 8, 47, 15, p.line)
    rect(d, 12, 39, 27, 42, p.accent); rect(d, 39, 36, 45, 41, p.glass)
    rect(d, 15, 45, 29, 47, p.line); rect(d, 42, 45, 48, 47, p.line)
    bolt(d, p, 11, 33); bolt(d, p, w - 14, 33)
    rect(s, 2, 43, 7, h - 4, p.deep); rect(s, w - 8, 41, w - 3, h - 4, p.deep)
    feetAndShadow(images, p, w, h, 7, w - 8)
  elseif name == "medical_cabinet" then
    steppedBody(s, p, 5, 2, w - 6, h - 3, 5)
    glass(g, p, 10, 11, w - 14, 47)
    rect(d, 17, 22, 33, 27, p.light); rect(d, 22, 17, 27, 32, p.light)
    rect(d, 13, 18, w - 17, 19, p.line); rect(d, 13, 36, w - 17, 37, p.line)
    rect(d, 15, 13, 19, 18, p.accent); rect(d, 31, 28, 35, 36, p.warm)
    rect(d, 12, 51, w - 16, 54, p.shade); rect(d, 16, 59, 34, 62, p.accent)
    rect(d, 14, 66, w - 18, 68, p.line); bolt(d, p, 9, 7); bolt(d, p, w - 12, 7)
    feetAndShadow(images, p, w, h, 8, w - 9)
  elseif name == "uv_sterilizer" then
    steppedBody(s, p, 5, 7, w - 6, h - 3, 5); rect(s, 10, 3, w - 11, 8, p.deep)
    glass(g, p, 10, 17, w - 14, 49)
    rect(g, 15, 22, w - 19, 25, p.accent); rect(g, 15, 38, w - 19, 41, p.screen)
    rect(g, 18, 20, 20, 45, p.light); rect(g, 25, 20, 27, 45, p.accent)
    rect(g, 32, 20, 34, 45, p.light); rect(g, 39, 20, 41, 45, p.accent)
    rect(d, 17, 53, 30, 56, p.accent); rect(d, 34, 53, 39, 56, p.line)
    bolt(d, p, 9, 12); bolt(d, p, w - 12, 12)
    feetAndShadow(images, p, w, h, 8, w - 9)
  elseif name == "diagnostic_console" then
    steppedBody(s, p, 3, 30, w - 4, h - 3, 6)
    rect(s, 11, 49, 18, h - 3, p.deep); rect(s, w - 20, 49, w - 13, h - 3, p.deep)
    screen(g, p, 9, 7, 47, 31); screen(g, p, 50, 11, w - 10, 33)
    line(d, 14, 24, 20, 20, p.glass); line(d, 20, 20, 25, 23, p.glass)
    line(d, 25, 23, 31, 15, p.glass); line(d, 31, 15, 41, 20, p.glass)
    line(d, 55, 24, 62, 18, p.glass); line(d, 62, 18, 68, 26, p.glass); line(d, 68, 26, 78, 19, p.glass)
    rect(d, 15, 42, 39, 44, p.accent); rect(d, 48, 42, 74, 44, p.line)
    for x = 51, 72, 7 do rect(d, x, 39, x + 3, 41, p.glass) end
    rect(d, 23, 34, 28, 37, p.deep); rect(d, 32, 34, 37, 37, p.shade)
    feetAndShadow(images, p, w, h, 10, w - 11)
  elseif name == "server_rack" then
    steppedBody(s, p, 5, 2, w - 6, h - 3, 5)
    for y = 11, 66, 11 do
      rect(d, 11, y, w - 15, y + 8, p.deep); rect(d, 15, y + 3, 34, y + 4, p.shade)
      rect(d, 39, y + 3, 43, y + 4, p.accent); rect(d, 46, y + 3, 48, y + 4, p.light)
    end
    for x = 13, 45, 8 do rect(d, x, 76, x + 3, 82, p.deep) end
    rect(d, 51, 12, 53, 70, p.line); pixel(d, 52, 16, p.light); pixel(d, 52, 38, p.accent); pixel(d, 52, 60, p.light)
    bolt(d, p, 9, 7); bolt(d, p, w - 12, 7)
    feetAndShadow(images, p, w, h, 8, w - 9)
  elseif name == "wall_display" then
    steppedBody(s, p, 2, 2, w - 3, h - 3, 5); screen(g, p, 8, 7, w - 11, h - 10)
    line(d, 14, 34, 25, 30, p.glass); line(d, 25, 30, 37, 33, p.glass)
    line(d, 37, 33, 49, 21, p.glass); line(d, 49, 21, 62, 25, p.glass)
    line(d, 62, 25, 77, 16, p.glass)
    rect(d, 71, 33, 77, 39, p.accent); rect(d, 80, 28, 86, 39, p.glass)
    bolt(d, p, 5, 6); bolt(d, p, w - 8, 6); bolt(d, p, 5, h - 9); bolt(d, p, w - 8, h - 9)
  elseif name == "signal_scope" then
    steppedBody(s, p, 7, 25, w - 8, h - 3, 4); screen(g, p, 10, 5, w - 11, 30)
    line(d, 15, 20, 24, 20, p.glass); line(d, 24, 20, 29, 13, p.glass)
    line(d, 29, 13, 33, 25, p.glass); line(d, 33, 25, 38, 18, p.glass); line(d, 38, 18, 45, 18, p.glass)
    rect(d, 19, 40, 36, 42, p.accent); rect(d, 40, 37, 44, 41, p.line)
    rect(d, 15, 46, 20, 49, p.deep); rect(d, 24, 46, 29, 49, p.shade); rect(d, 34, 46, 39, 49, p.deep)
    vent(d, p, 18, 52, 22, 2)
    rect(s, 27, 1, 31, 5, p.deep); rect(s, 25, 1, 33, 2, p.line)
    feetAndShadow(images, p, w, h, 10, w - 11)
  elseif name == "drone_dock" then
    steppedBody(s, p, 4, 29, w - 5, h - 3, 5)
    rect(s, 11, 18, w - 12, 22, p.shade)
    rect(s, 26, 7, 53, 23, p.deep); rect(s, 22, 11, 57, 19, p.deep)
    rect(s, 29, 8, 50, 22, p.panel); rect(s, 24, 13, 55, 17, p.panel)
    rect(s, 33, 10, 46, 20, p.shade); rect(s, 36, 20, 43, 30, p.line)
    rect(g, 36, 12, 43, 18, p.screen); rect(g, 38, 13, 41, 16, p.accent)
    rect(g, 27, 14, 31, 18, p.accent); rect(g, 49, 14, 53, 18, p.accent)
    pixel(d, 32, 9, p.light); pixel(d, 48, 9, p.light); bolt(d, p, 28, 20); bolt(d, p, 49, 20)
    rect(d, 20, 36, 60, 39, p.accent); rect(d, 25, 44, 55, 46, p.deep)
    bolt(d, p, 8, 34); bolt(d, p, w - 11, 34)
    feetAndShadow(images, p, w, h, 8, w - 9)
  else
    error("Unknown prop: " .. name)
  end
end

for _, spec in ipairs(specs) do
  local palette = colorize(themes[spec.theme])
  local sprite = Sprite(spec.w, spec.h, ColorMode.RGB)
  sprite:deleteLayer(sprite.layers[1])

  local shadowLayer = sprite:newLayer(); shadowLayer.name = "contact_shadow"
  local structureLayer = sprite:newLayer(); structureLayer.name = "structure"
  local glassLayer = sprite:newLayer(); glassLayer.name = "glass_and_screens"
  local detailsLayer = sprite:newLayer(); detailsLayer.name = "functional_details"

  local images = {
    shadow = Image(sprite.spec),
    structure = Image(sprite.spec),
    glass = Image(sprite.spec),
    details = Image(sprite.spec),
  }
  for _, image in pairs(images) do image:clear(transparent) end
  drawProp(spec.name, images, palette, spec.w, spec.h)

  local frame = sprite.frames[1]
  sprite:newCel(shadowLayer, frame, images.shadow, Point(0, 0))
  sprite:newCel(structureLayer, frame, images.structure, Point(0, 0))
  sprite:newCel(glassLayer, frame, images.glass, Point(0, 0))
  sprite:newCel(detailsLayer, frame, images.details, Point(0, 0))

  local themeDir = app.fs.joinPath(outputRoot, spec.theme)
  local outputPath = app.fs.joinPath(themeDir, spec.theme .. "_" .. spec.name .. ".aseprite")
  sprite:saveAs(outputPath)
  sprite:close()
end
