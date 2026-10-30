from "%rGui/globals/ui_library.nut" import *
from "%rGui/shipFireControlCommon.nut" import weaponPalette

const RESERVE_AMMO_PREFERRED_PER_ROW = 3
const RESERVE_AMMO_ROWS = 2
const RESERVE_AMMO_MAX_ROW = 4
const MAX_RESERVE_AMMO = 8

const reserveDotSize = hdpx(5)
const reserveGap = hdpx(2)
let dotSize = max(1, (reserveDotSize + 0.5).tointeger())
let dotSizeArr = [dotSize, dotSize]
let reserveBlockSize = [
  RESERVE_AMMO_MAX_ROW * dotSize + (RESERVE_AMMO_MAX_ROW - 1) * reserveGap,
  RESERVE_AMMO_ROWS * dotSize + (RESERVE_AMMO_ROWS - 1) * reserveGap
]

let reserveImages = {}

function reserveImage(isFull) {
  let key = isFull ? "full" : "empty"
  local img = reserveImages?[key]
  if (img == null) {
    img = Picture($"+ui/gameuiskin#torpedo_ammo_{key}.svg:{dotSize}:{dotSize}:P")
    reserveImages[key] <- img
  }
  return img
}

function splitReserveRows(capacity) {
  let rows = min(RESERVE_AMMO_ROWS,
    (capacity + RESERVE_AMMO_PREFERRED_PER_ROW - 1) / RESERVE_AMMO_PREFERRED_PER_ROW)
  let res = []
  local rest = capacity
  for (local r = 0; r < rows; ++r) {
    let n = (rest + (rows - r) - 1) / (rows - r)
    res.append(n)
    rest -= n
  }
  return res
}

function mkReserveAmmo(params) {
  let { total, left, colorFull, colorEmpty } = params

  let capacity = min(total, MAX_RESERVE_AMMO)
  let rows = splitReserveRows(capacity)
  let spentCount = capacity - left

  let children = []
  local idx = 0
  foreach (n in rows) {
    let rowChildren = []
    for (local j = 0; j < n; ++j) {
      let isFull = idx >= spentCount
      rowChildren.append({
        size = dotSizeArr
        rendObj = ROBJ_IMAGE
        image = reserveImage(isFull)
        color = isFull ? colorFull : colorEmpty
      })
      idx++
    }
    children.append({
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = reserveGap
      children = rowChildren
    })
  }

  return {
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    gap = reserveGap
    children
  }
}

let mkReserveBlock = @(weaponState) function() {
  let st = weaponState.get()
  let palette = weaponPalette(st)
  return {
    watch = weaponState
    size = reserveBlockSize
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = mkReserveAmmo({
      total = st.reserveTotal
      left = st.reserveLeft
      colorFull = palette.ready
      colorEmpty = palette.spent
    })
  }
}

return freeze({
  mkReserveBlock
})
