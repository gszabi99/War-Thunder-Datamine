local { generateQrBlocks } = require("std/qrCode.nut")

local mulArr = @(arr, mul) arr.map(@(v) v * mul)

local function mkQrCode(data, size = ::hdpx(400), darkColor = 0xFF000000, lightColor = 0xFFFFFFFF) {
  local list = generateQrBlocks(data)
  local cellSize = (size.tofloat() / (list.size + 2)).tointeger()
  return {
    size = array(2, cellSize * (list.size + 2))
    padding = cellSize
    rendObj = ROBJ_SOLID
    color = lightColor
    children = list.list.map(@(b) {
      size = mulArr(b.size, cellSize)
      pos = mulArr(b.pos, cellSize)
      rendObj = ROBJ_SOLID
      color = darkColor
    })
  }
}

return ::kwarg(mkQrCode)