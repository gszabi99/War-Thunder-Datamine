from "%rGui/globals/ui_library.nut" import *
let { mkBitmapPicture, mkBitmapPictureLazy, setMaxCachedSize } = require("%darg/helpers/bitmap.nut")
let { sqrt } = require("math")

setMaxCachedSize(max(sw(15) * sh(15), 128 * 128))

let gradTexSize = 64
let colorParts = @(color) {
  r = (color >> 16) & 0xFF
  g = (color >> 8) & 0xFF
  b = color & 0xFF
  a = (color >> 24) & 0xFF
}
let partsToColor = @(c) Color(c.r, c.g, c.b, c.a)
let mkWhite = @(part) part + (part << 8) + (part << 16) + (part << 24)

let lerpColorParts = @(c1, c2, value) value <= 0 ? c1
  : value >= 1 ? c2
  : c1.map(@(v1, k) v1 + ((c2[k] - v1) * value + 0.5).tointeger())

let getDistance = @(x, y) sqrt(x * x + y * y)
let getDistanceSq = @(x, y) x * x + y * y

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

let mkGradientCtorDoubleSideY = @(color1, color2, middle = 0.4) function(params, bmp) {
  let { w, h } = params
  let c1 = colorParts(color1)
  let c2 = colorParts(color2)
  for (local y = 0; y < h; y++) {
    let rel = y.tofloat() / (h - 1)
    let v = rel < middle ? rel / middle
      : rel > 1.0 - middle ? (1.0 - rel) / middle
      : 1.0
    let color = partsToColor(lerpColorParts(c1, c2, v))
    for (local x = 0; x < w; x++)
      bmp.setPixel(x, y, color)
  }
}

//p1, p2 : array(2)
let mkGradientCtorInclined = function(color1, color2, p1, p2) {
  let x1 = p1[0]
  let x2 = p2[0]
  let y1 = p1[1]
  let y2 = p2[1]
  let dx = x2 - x1
  let dy = y2 - y1
  if (dx == 0) {
    log("mkGradientCtorInclined does not support gradient with x0 == x1. Use mkColoredGradientY instead.")
    return @(_, __) null
  }
  return function(params, bmp) {
    let { w, h } = params
    local startTop = (w - 1).tofloat() * (x1 + y1 * dy / dx)
    let startFullDiff = -(w - 1).tofloat() * dy / dx
    local width = (w - 1).tofloat() * (dx + dy * dy / dx)
    let colorStart = width < 0 ? color2 : color1
    let colorEnd = width < 0 ? color1 : color2
    let c1 = colorParts(colorStart)
    let c2 = colorParts(colorEnd)
    if (width < 0) {
      startTop = startTop + width
      width = -width
    }
    for (local y = 0; y < h; y++) {
      let start = startTop + y * startFullDiff / (h - 1)
      for (local x = 0; x < w; x++) {
        let xf = x.tofloat()
        let color = xf <= start ? colorStart
          : xf >= start + width ? colorEnd
          : partsToColor(lerpColorParts(c1, c2, (xf - start) / width))
        bmp.setPixel(x, h - 1 - y, color)
      }
    }
  }
}

let gradTranspDoubleSideX = mkBitmapPicture(gradTexSize, 4, mkGradientCtorDoubleSideX(0, 0xFFFFFFFF))

let gradCircCornerSize = 20
let gradCircFullSize = 2 * gradCircCornerSize + 4
let gradCircularSqCorners = mkBitmapPicture(gradCircFullSize, gradCircFullSize,
  function(_, bmp) {
    let rel = array(gradCircFullSize).map(@(_, v)
      (v < gradCircCornerSize ? gradCircCornerSize - v
        : max(0, v - gradCircFullSize + gradCircCornerSize + 1)).tofloat()
      / gradCircCornerSize)
    foreach (x, xRel in rel)
      foreach (y, yRel in rel)
        bmp.setPixel(x, y, mkWhite((0xFF * (1.0 - min(1.0, getDistanceSq(xRel, yRel)))).tointeger()))
  })

let gradCircularSmallHorCorners = mkBitmapPicture(gradCircFullSize, gradCircFullSize,
  function(_, bmp) {
    let rel = array(gradCircFullSize).map(@(_, v)
      (v < gradCircCornerSize ? gradCircCornerSize - v
        : max(0, v - gradCircFullSize + gradCircCornerSize + 1)).tofloat()
      / gradCircCornerSize)
    foreach (x, xRel in rel)
      foreach (y, yRel in rel)
        bmp.setPixel(x, y, mkWhite((0xFF * (1.0 - min(1.0, getDistance(xRel, 0.6 * yRel)))).tointeger()))
  })

let gradRadial = mkBitmapPicture(gradCircCornerSize * 2, gradCircCornerSize * 2,
  function(_, bmp) {
    for (local y = 0; y < gradCircCornerSize * 2; y++)
      for (local x = 0; x < gradCircCornerSize * 2; x++) {
        let distance = getDistance(x - gradCircCornerSize, y - gradCircCornerSize)
        bmp.setPixel(x, y, mkWhite((0xFF * max(0.0, 1.0 - ((distance + 1) / gradCircCornerSize))).tointeger()))
      }
  })

let gradRadialSq = mkBitmapPicture(gradCircCornerSize * 2, gradCircCornerSize * 2,
  function(_, bmp) {
    for (local y = 0; y < gradCircCornerSize * 2; y++)
      for (local x = 0; x < gradCircCornerSize * 2; x++) {
        let distance = getDistance(x - gradCircCornerSize, y - gradCircCornerSize) / gradCircCornerSize
        let mult = max(0.0, 1.0 - distance)
        bmp.setPixel(x, y, mkWhite((0xFF * mult * mult).tointeger()))
      }
  })

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

let simpleHorGrad = mkBitmapPicture(10, 2,
  function(params, bmp) {
    let { w, h } = params
    for (local x = 0; x < w; x++) {
      let color = mkWhite((0xFF * x.tofloat() / (w - 1) + 0.5).tointeger())
      for (local y = 0; y < h; y++)
        bmp.setPixel(x, y, color)
    }
  })

let simpleVerGrad = mkBitmapPicture(2, 10,
  function(params, bmp) {
    let { w, h } = params
    for (local y = 0; y < h; y++) {
      let color = mkWhite((0xFF * y.tofloat()/ (h - 1) + 0.5).tointeger())
      for (local x = 0; x < w; x++)
        bmp.setPixel(x, y, color)
    }
  })

let simpleVerGradInv = mkBitmapPicture(2, 10,
  function(params, bmp) {
    let { w, h } = params
    for (local y = 0; y < h; y++) {
      let color = mkWhite(0xFF - (0xFF * y.tofloat() / (h - 1) + 0.5).tointeger())
      for (local x = 0; x < w; x++)
        bmp.setPixel(x, y, color)
    }
  })

let mkColoredGradientY = @(colorTop, colorBottom, height = 12)
  mkBitmapPicture(4, height,
    function(params, bmp) {
      let { w, h } = params
      let c1 = colorParts(colorBottom)
      let c2 = colorParts(colorTop)
      for (local y = 0; y < h; y++) {
        let color = partsToColor(lerpColorParts(c1, c2, y.tofloat() / (h - 1)))
        for (local x = 0; x < w; x++)
          bmp.setPixel(x, y, color)
      }
    })


let mkFontGradient = @(colorTop, colorBottom, height = 11, middle = 6, spread = 2)
  mkBitmapPicture(4, height,
    function(params, bmp) {
      let { w, h } = params
      let c1 = colorParts(colorBottom)
      let c2 = colorParts(colorTop)
      let y1 = middle - spread - 1
      let y2 = middle + spread - 1
      for (local y = 0; y < h; y++) {
        let color = y <= y1 ? colorBottom
          : y >= y2 ? colorTop
          : partsToColor(lerpColorParts(c1, c2, (y - y1).tofloat() / (spread * 2)))
        for (local x = 0; x < w; x++)
          bmp.setPixel(x, y, color)
      }
    })

let function mkRingGradientLazy(radius, outherWidth, innerWidth) {
  let center = radius + outherWidth + 1
  let size = 2 * center
  return mkBitmapPictureLazy(size, size,
    function(_, bmp) {
      for (local y = 0; y < size; y++)
        for (local x = 0; x < size; x++) {
          let distance = getDistance(0.5 + x - center, 0.5 + y - center) - radius
          let mul = distance >= 0 ? distance / outherWidth : -distance / innerWidth
          bmp.setPixel(x, y, mkWhite((0xFF * max(0.0, 1.0 - mul)).tointeger()))
        }
    })
}

return {
  //const
  gradTexSize
  gradDoubleTexOffset = (0.5 * gradTexSize).tointeger() - 2
  gradCircCornerOffset = gradCircCornerSize + 1

  //std gradietns
  gradTranspDoubleSideX
  gradCircularSqCorners
  gradCircularSmallHorCorners
  gradRadial
  gradRadialSq
  simpleHorGrad
  simpleVerGrad
  simpleVerGradInv

  //ctors
  mkGradientCtorDoubleSideX
  mkGradientCtorDoubleSideY
  mkGradientCtorInclined
  mkGradientCtorRadial
  mkColoredGradientY
  mkFontGradient
  mkRingGradientLazy
}