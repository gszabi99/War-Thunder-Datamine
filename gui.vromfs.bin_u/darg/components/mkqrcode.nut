from "%darg/ui_imports.nut" import *
let { generateQrBlocks } = require("%sqstd/qrCode.nut")

let mulArr = @(arr, mul) arr.map(@(v) v * mul)

let function mkQrCode(data, size = hdpx(400), darkColor = 0xFF000000, lightColor = 0xFFFFFFFF) {
  let list = generateQrBlocks(data)
  let cellSize = (size.tofloat() / (list.size + 2)).tointeger()
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

return kwarg(mkQrCode)