from "%darg/helpers/bitmap.nut" import mkBitmapPicture, setMaxCachedSize,
  mkBitmapPictureLazy
from "math" import sqrt
from "%rGui/globals/ui_library.nut" import *

setMaxCachedSize(max(sw(15) * sh(15), 128 * 128))

const gradTexSize = 64
let colorParts = @(color) {
  r = (color >> 16) & 0xFF
  g = (color >> 8) & 0xFF
  b = color & 0xFF
  a = (color >> 24) & 0xFF
}
let partsToColor = @(c) Color(c.r, c.g, c.b, c.a)

let lerpColorParts = @(c1, c2, value) value <= 0 ? c1
  : value >= 1 ? c2
  : c1.map(@(v1, k) v1 + ((c2[k] - v1) * value + 0.5).tointeger())

let mkWhite = @(part) part + (part << 8) + (part << 16) + (part << 24)

let getDistance = @(x, y) sqrt(x * x + y * y)

let mkGradientCtorDoubleSideX = @(color1, color2, middle = 0.4) function(params, bmp) {
  let { w, h } = params
  let c1 = colorParts(color1)
  let c2 = colorParts(color2)
  for (local x = 0; x < w; x++) {
    let rel = x.tofloat() / (w - 1)
    let v = rel < middle ? rel / middle
      : rel > 1.0 - middle ? (1.0 - rel) / middle
      : 1.0
    let color = partsToColor(lerpColorParts(c1, c2, v))
    for (local y = 0; y < h; y++)
      bmp.setPixel(x, y, color)
  }
}

let gradTranspDoubleSideX = mkBitmapPicture(gradTexSize, 4, mkGradientCtorDoubleSideX(0, 0xFFFFFFFF))

let mkGradientCtorRadial = @(color1, color2, r1, gradWidth, cx, cy) function(params, bmp) {
  let { w, h } = params
  let r2 = r1 + gradWidth
  let c1 = colorParts(color1)
  let c2 = colorParts(color2)
  for (local y = 0; y < h; y++)
    for (local x = 0; x < w; x++) {
      let r = getDistance(x - cx, y - cy)
      let color = r <= r1 ? color1
        : r >= r2 ? color2
        : partsToColor(lerpColorParts(c1, c2, (r - r1) / gradWidth))
      bmp.setPixel(x, h - 1 - y, color)
    }
}

let mkColoredGradientX = @(colorLeft, colorRight, width = 12, isAlphaPremultiplied = true)
  mkBitmapPicture(width, 4,
    function(params, bmp) {
      let { w, h } = params
      let c1 = colorParts(colorLeft)
      let c2 = colorParts(colorRight)
      for (local x = 0; x < w; x++) {
        let color = partsToColor(lerpColorParts(c1, c2, x.tofloat() / (w - 1)))
        for (local y = 0; y < h; y++)
          bmp.setPixel(x, y, color)
      }
    }, isAlphaPremultiplied ? "" : "!")


let mkVertScrollMaskLazy = @(imgHeight, fadeBtm, fadeTop)
  mkBitmapPictureLazy(2, imgHeight,
    function(params, bmp) {
      let { w, h } = params
      for(local y = 0; y < h; y++) {
        let alphaFactor = y < fadeBtm ? y.tofloat() / fadeBtm
          : y > h - 1 - fadeTop ? (h - 1 - y).tofloat() / fadeTop
          : 1
        let part = (0xFF * alphaFactor).tointeger()
        let color = mkWhite(part)
        for(local x = 0; x < w; x++)
          bmp.setPixel(x, y, color)
      }
    }
  )


return {
  gradTexSize
  gradTranspDoubleSideX
  mkVertScrollMaskLazy
  mkGradientCtorRadial
  mkColoredGradientX
}