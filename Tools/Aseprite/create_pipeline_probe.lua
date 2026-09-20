local outputDir = app.params["output_dir"]
if outputDir == nil or outputDir == "" then
  error("Missing --script-param output_dir=<absolute directory>")
end

local function rgba(r, g, b, a)
  return app.pixelColor.rgba(r, g, b, a or 255)
end

local transparent = rgba(0, 0, 0, 0)
local palette = {
  outline = rgba(18, 22, 28),
  deep = rgba(35, 43, 52),
  mid = rgba(65, 77, 87),
  light = rgba(105, 119, 124),
  bronze = rgba(139, 91, 48),
  bronzeLight = rgba(204, 145, 70),
  amber = rgba(255, 190, 72),
  warning = rgba(205, 67, 52),
}

local function fillRect(image, x, y, width, height, color)
  for py = y, y + height - 1 do
    for px = x, x + width - 1 do
      image:drawPixel(px, py, color)
    end
  end
end

local function drawBody(image)
  image:clear(transparent)
  fillRect(image, 5, 9, 22, 17, palette.outline)
  fillRect(image, 7, 7, 18, 2, palette.outline)
  fillRect(image, 7, 10, 18, 14, palette.deep)
  fillRect(image, 9, 11, 14, 8, palette.mid)
  fillRect(image, 10, 12, 12, 2, palette.light)
  fillRect(image, 8, 24, 5, 3, palette.outline)
  fillRect(image, 19, 24, 5, 3, palette.outline)
end

local function drawDetails(image, frameNumber)
  image:clear(transparent)
  fillRect(image, 8, 20, 16, 2, palette.bronze)
  fillRect(image, 10, 21, 12, 1, palette.bronzeLight)
  fillRect(image, 10, 15, 2, 2, palette.warning)
  fillRect(image, 14, 15, 2, 2, palette.deep)
  fillRect(image, 18, 15, 2, 2, palette.deep)

  local indicatorX = 10 + ((frameNumber - 1) % 3) * 4
  fillRect(image, indicatorX, 15, 2, 2, palette.amber)
end

local sprite = Sprite(32, 32, ColorMode.RGB)
sprite:deleteLayer(sprite.layers[1])

local bodyLayer = sprite:newLayer()
bodyLayer.name = "body"
local detailLayer = sprite:newLayer()
detailLayer.name = "details"

for frameNumber = 2, 4 do
  sprite:newEmptyFrame()
end

for frameNumber = 1, 4 do
  local frame = sprite.frames[frameNumber]
  frame.duration = 0.12

  local bodyImage = Image(sprite.spec)
  drawBody(bodyImage)
  sprite:newCel(bodyLayer, frame, bodyImage, Point(0, 0))

  local detailImage = Image(sprite.spec)
  drawDetails(detailImage, frameNumber)
  sprite:newCel(detailLayer, frame, detailImage, Point(0, 0))
end

local tag = sprite:newTag(sprite.frames[1], sprite.frames[4])
tag.name = "pulse"
tag.aniDir = AniDir.PING_PONG

local asepritePath = app.fs.joinPath(outputDir, "native32_pipeline_probe.aseprite")
sprite:saveAs(asepritePath)
sprite:close()

