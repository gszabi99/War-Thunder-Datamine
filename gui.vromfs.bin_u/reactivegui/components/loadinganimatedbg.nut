



from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import objPx
from "%rGui/components/text.nut" import pictureName
from "%appGlobals/loading/loadingBgChoice.nut" import loadingBgBlkPath
from "daRg" import get_mouse_cursor_pos
from "dagor.time" import get_time_msec
from "math" import abs, clamp
import "%appGlobals/style/cssColorToInt.nut" as cssColorToInt
import "%rGui/style/cssColor.nut" as cssColor
import "DataBlock" as DataBlock

const BLEND_MS = 500.0
const COLOR_WHITE = 0xFFFFFFFF

let readProp = @(blk, name) blk?[name]


function readFloat(blk, name) {
  let text = readProp(blk, name) ?? ""
  local end = text.startswith("-") || text.startswith("+") ? 1 : 0
  local hasDot = false
  while (end < text.len() && ((text[end] >= '0' && text[end] <= '9') || (text[end] == '.' && !hasDot))) {
    hasDot = hasDot || text[end] == '.'
    end++
  }
  let num = text.slice(0, end)
  return num == "" || num == "-" || num == "+" || num == "." ? 0.0 : num.tofloat()
}

let toColor = @(v) v == null ? null : v.startswith("@") ? cssColor(v.slice(1)) : cssColorToInt(v)


function readPair(text, units) {
  let parts = text.split(",")
  return [objPx(parts[0].strip(), units), parts.len() > 1 ? objPx(parts[1].strip(), units) : 0]
}



function readSize(blk, units) {
  let size = readProp(blk, "size")
  let [w, h] = size != null ? readPair(size, units) : [units.pw, units.ph]
  units.__update({ w, h })
  let height = readProp(blk, "height")
  let width = readProp(blk, "width")
  if (height != null)
    units.h = objPx(height, units)
  if (width != null)
    units.w = objPx(width, units)
  if (height != null)
    units.h = objPx(height, units)
  return [units.w, units.h]
}

function readRotation(blk, units) {
  let angle = readFloat(blk, "rotation") % 360.0
  let center = readProp(blk, "rotation-center")
  if ((center ?? "") == "")
    return { angle, pivot = const [0.5, 0.5] }
  let [cx, cy] = readPair(center, units)
  return { angle, pivot = [units.w > 0 ? cx.tofloat() / units.w : 0.5, units.h > 0 ? cy.tofloat() / units.h : 0.5] }
}



function mkParallax() {
  let state = { mx = 0, lastMs = get_time_msec(), deviation = 0.0 }
  return function deviation() {
    let now = get_time_msec()
    if (now == state.lastMs)
      return state.deviation
    let blendK = 4.0 * (now - state.lastMs) / BLEND_MS
    state.lastMs = now
    let rootW = sw(100)
    let target = clamp(get_mouse_cursor_pos().x, 0, rootW).tointeger()
    if (target == state.mx)
      return state.deviation
    let dx = (target - state.mx) * blendK
    state.mx = blendK > 1 ? target
      : (state.mx + (abs(dx) < 1 ? (dx < 0 ? -1 : 1) : dx)).tointeger()
    state.deviation = state.mx - 0.5 * rootW
    return state.deviation
  }
}

function mkElem(blk, parentSize, parallax) {
  let units = { pw = parentSize[0], ph = parentSize[1], w = 0, h = 0 }
  let isLayer = blk.getBlockName() == "imgLayer"
  let size = readSize(blk, units)
  let pos = readProp(blk, "pos")
  let image = readProp(blk, "background-image")
  let color = toColor(readProp(blk, "background-color"))
  let { angle, pivot } = readRotation(blk, units)
  let children = []
  for (local i = 0; i < blk.blockCount(); i++)
    children.append(mkElem(blk.getBlock(i), size, parallax))

  let res = { size, children }
  if (pos != null)
    res.pos <- readPair(pos, units)
  
  if (image != null)
    res.__update({ rendObj = ROBJ_IMAGE, image = Picture(pictureName(image)), color = color ?? COLOR_WHITE,
      flipX = readPair(readProp(blk, "background-position") ?? "0", units)[0] == size[0] })
  else if (color != null)
    res.__update({ rendObj = ROBJ_SOLID, color })

  let sens = isLayer ? 0.01 * readFloat(blk, "layerSensitivity") : 0.0
  let rotSens = isLayer ? 0.01 * readFloat(blk, "rotation-sensitivity") : 0.0
  if (sens == 0 && rotSens == 0)
    return angle == 0 ? res : res.__update({ transform = { rotate = angle, pivot } })
  let last = { deviation = null }
  return res.__update({
    transform = { rotate = angle, pivot }
    behavior = Behaviors.RtPropUpdate
    
    update = function() {
      let deviation = parallax()
      if (deviation == last.deviation)
        return null
      last.deviation = deviation
      return { transform = { translate = [(sens * deviation).tointeger(), 0], rotate = angle + rotSens * deviation, pivot } }
    }
  })
}


function boxAt(sizeExpr, posExpr, parentSize) {
  let units = { pw = parentSize[0], ph = parentSize[1], w = 0, h = 0 }
  let size = readPair(sizeExpr, units)
  units.w = size[0]
  units.h = size[1]
  return { size, pos = readPair(posExpr, units) }
}

function mkLayers(name, frameSize, parallax) {
  let blk = DataBlock()
  if ((name ?? "") == "" || !blk.tryLoad(loadingBgBlkPath(name)))
    return null
  let box = boxAt("2.5sh, sh", "pw/2-w/2, ph/2-h/2", frameSize)
  let children = []
  for (local i = 0; i < blk.blockCount(); i++)
    children.append(mkElem(blk.getBlock(i), box.size, parallax))
  return box.__update({ children })
}

let mkGradient = @(posExpr, frameSize) boxAt("0.333sh, sh", posExpr, frameSize).__update({
  rendObj = ROBJ_IMAGE
  image = Picture("!ui/gameuiskin#debriefing_bg_grad@@ss")
  color = 0xFF000000
})

function loadingAnimatedBg(bgName) {
  let nameW = type(bgName) == "string" ? null : bgName
  
  let parallax = mkParallax()
  return function() {
    let frame = boxAt("2.333sh, sh", "50%sw-50%w, 50%sh-50%h", const [sw(100), sh(100)])
    return {
      watch = nameW
      size = const [sw(100), sh(100)]
      rendObj = ROBJ_SOLID
      color = 0xFF000000
      children = frame.__update({
        clipChildren = true
        children = [mkLayers(nameW == null ? bgName : nameW.get(), frame.size, parallax),
          mkGradient("-w/2, 0", frame.size), mkGradient("pw -w/2, 0", frame.size)]
      })
    }
  }
}

return loadingAnimatedBg
