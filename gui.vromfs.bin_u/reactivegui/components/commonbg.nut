


from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import pictureName
import "%appGlobals/style/cssColorToInt.nut" as cssColorToInt


let patternSizeMul = cssConst("dp")

let toColor = @[pure, nodiscard] (c) type(c) == "string" ? cssColorToInt(c) : c


function offsets(text) {
  if (text == null)
    return [0, 0, 0, 0]
  let v = text.split(",").map(@(s) px(s.strip()))
  let l = v[0]
  let t = v?[1] ?? l
  return [l, t, v?[2] ?? l, v?[3] ?? t]
}

let isSvg = @(image) image.indexof(".svg") != null

function mkTiles(pic, color, tile, size) {
  let cols = (size[0] + tile - 1) / tile
  let rows = (size[1] + tile - 1) / tile
  let children = []
  for (local y = 0; y < rows; y++)
    for (local x = 0; x < cols; x++)
      children.append({ pos = [x * tile, y * tile], size = tile, rendObj = ROBJ_IMAGE, image = pic, color })
  return children
}

function commonBg(p) {
  let color = toColor(p?.bgcolor ?? 0xFFFFFFFF)
  let image = p?.image
  let layers = []
  if (image == null)
    layers.append({ size = flex(), rendObj = ROBJ_SOLID, color })
  else {
    let pic = Picture(pictureName(image))
    let [l, t, r, b] = offsets(p?.position)
    let repeat = p?.repeat ?? "stretch"
    if (repeat == "expand") {
      let mul = isSvg(image) ? 1 : patternSizeMul
      layers.append({
        size = flex(), rendObj = ROBJ_9RECT, image = pic, color
        texOffs = [t, r, b, l], screenOffs = [t * mul, r * mul, b * mul, l * mul]
      })
    }
    else if (repeat == "repeat")
      layers.append({
        size = flex(), padding = [t, r, b, l], clipChildren = true
        children = mkTiles(pic, color, p.tile * patternSizeMul, p.size)
      })
    else
      layers.append({ size = flex(), padding = [t, r, b, l], children = {
        size = flex(), rendObj = ROBJ_IMAGE, image = pic, color, keepAspect = repeat == "aspect-ratio" ? KEEP_ASPECT_FIT : null } })
  }
  if (p?.border)
    layers.append({ size = flex(), rendObj = ROBJ_FRAME, color = toColor(p.borderColor), borderWidth = patternSizeMul })
  return layers
}

return freeze({ commonBg, toColor })
