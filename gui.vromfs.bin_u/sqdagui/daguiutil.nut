from "%sqDagui/daguiNativeApi.nut" import *

let { format } = require("string")
let { Color4 } = require("dagor.math")
let { hexStringToInt } =  require("%sqstd/string.nut")
let regexp2 = require("regexp2")
let { wrapIdxInArrayLen } = require("%sqStdLibs/helpers/u.nut")
let math = require("math")

enum ALIGN {
  LEFT   = "left"
  TOP    = "top"
  RIGHT  = "right"
  BOTTOM = "bottom"
  CENTER = "center"
}

let DEFAULT_OVERRIDE_PARAMS = {
  windowSizeX = -1
  windowSizeY = -1
}

let check_obj = @(obj) obj != null && obj.isValid()







function toPixels(guiScene, value, obj = null) {
  if (type(value) == "float" || type(value) == "integer")
    return value.tointeger()
  if (type(value) == "string")
    return guiScene.calcString(value, obj)
  return 0
}














function countSizeInItems(listObj, sizeX, sizeY, spaceX, spaceY, reserveX = 0, reserveY = 0) {
  let res = {
    itemsCountX = 1
    itemsCountY = 1
    sizeX = 0
    sizeY = 0
    spaceX = 0
    spaceY = 0
    reserveX = 0
    reserveY = 0
  }
  if (!check_obj(listObj))
    return res

  let listSize = listObj.getSize()
  let guiScene = listObj.getScene()
  res.sizeX = toPixels(guiScene, sizeX)
  res.sizeY = toPixels(guiScene, sizeY)
  res.spaceX = toPixels(guiScene, spaceX)
  res.spaceY = toPixels(guiScene, spaceY)
  res.reserveX = toPixels(guiScene, reserveX)
  res.reserveY = toPixels(guiScene, reserveY)
  res.itemsCountX = math.max(1, ((listSize[0] - res.spaceX - res.reserveX) / (res.sizeX + res.spaceX)).tointeger())
  res.itemsCountY = math.max(1, ((listSize[1] - res.spaceY - res.reserveY) / (res.sizeY + res.spaceY)).tointeger())
  return res
}


function adjustWindowSizeByConfig(wndObj, listObj, config, overrideParams = DEFAULT_OVERRIDE_PARAMS) {
  if (!check_obj(wndObj) || !check_obj(listObj))
    return [0, 0]

  overrideParams = DEFAULT_OVERRIDE_PARAMS.__merge(overrideParams)
  let wndSize = wndObj.getSize()
  let listSize = listObj.getSize()
  let windowSizeX = overrideParams.windowSizeX
  let windowSizeY = overrideParams.windowSizeY

  let wndSizeX = windowSizeX != -1 ? windowSizeX
    : math.min(wndSize[0], wndSize[0] - listSize[0] + (config.spaceX + config.itemsCountX * (config.sizeX + config.spaceX)))
  let wndSizeY = windowSizeY != -1 ? windowSizeY
    : math.min(wndSize[1], wndSize[1] - listSize[1] + (config.spaceY + config.itemsCountY * (config.sizeY + config.spaceY)))
  wndObj.size = format("%d, %d", wndSizeX, wndSizeY)
  return [wndSizeX, wndSizeY]
}
















function adjustWindowSize(wndObj, listObj, sizeX, sizeY, spaceX, spaceY, overrideParams = DEFAULT_OVERRIDE_PARAMS) {
  let res = countSizeInItems(listObj, sizeX, sizeY, spaceX, spaceY)
  local windowSize = adjustWindowSizeByConfig(wndObj, listObj, res, overrideParams)
  return res.__update({ windowSize })
}


function setObjPosition(obj, reqPos_, border_) {
  if (!check_obj(obj))
    return

  let guiScene = obj.getScene()

  guiScene.applyPendingChanges(true)

  let objSize = obj.getSize()
  let screenSize = [ screen_width(), screen_height() ]
  let reqPos = [toPixels(guiScene, reqPos_[0], obj), toPixels(guiScene, reqPos_[1], obj)]
  let border = [toPixels(guiScene, border_[0], obj), toPixels(guiScene, border_[1], obj)]

  let posX = math.clamp(reqPos[0], border[0], screenSize[0] - border[0] - objSize[0])
  let posY = math.clamp(reqPos[1], border[1], screenSize[1] - border[1] - objSize[1])

  if (obj?.pos != null)
    obj.pos = format("%d, %d", posX, posY)
  else {
    obj.left = format("%d", posX)
    obj.top =  format("%d", posY)
  }
}














let checkAlignsMap = {
  [ALIGN.BOTTOM] = [ ALIGN.BOTTOM, ALIGN.TOP, ALIGN.RIGHT, ALIGN.LEFT, ALIGN.BOTTOM ],
  [ALIGN.TOP] = [ ALIGN.TOP, ALIGN.BOTTOM, ALIGN.RIGHT, ALIGN.LEFT, ALIGN.TOP ],
  [ALIGN.RIGHT] = [ ALIGN.RIGHT, ALIGN.LEFT, ALIGN.BOTTOM, ALIGN.TOP, ALIGN.RIGHT ],
  [ALIGN.LEFT] = [ ALIGN.LEFT, ALIGN.RIGHT, ALIGN.BOTTOM, ALIGN.TOP, ALIGN.LEFT ],
  def = [ ALIGN.BOTTOM, ALIGN.RIGHT, ALIGN.TOP, ALIGN.LEFT, ALIGN.BOTTOM ]
}

let vertPosMap = {
  [ALIGN.TOP] = { isPositive = false },
  [ALIGN.RIGHT] = { isVertical = false },
  [ALIGN.LEFT] =  { isVertical = false, isPositive = false}
}
function setPopupMenuPosAndAlign(parentObjOrPos, defAlign, menuObj, params = null) {
  if (!check_obj(menuObj))
    return defAlign

  let guiScene = menuObj.getScene()
  let menuSize = menuObj.getSize()

  local parentPos  = [0, 0]
  local parentSize = [0, 0]
  if (type(parentObjOrPos) == "instance" && check_obj(parentObjOrPos)) {
    parentPos  = parentObjOrPos.getPosRC()
    parentSize = parentObjOrPos.getSize()
  }
  else if ((type(parentObjOrPos) == "array") && parentObjOrPos.len() == 2) {
    parentPos[0] = toPixels(guiScene, parentObjOrPos[0])
    parentPos[1] = toPixels(guiScene, parentObjOrPos[1])
  }
  else if (parentObjOrPos == null) {
    parentPos  = get_dagui_mouse_cursor_pos_RC()
  }

  let margin = params?.margin
  if (margin && margin.len() >= 2)
    for (local i = 0; i < 2; i++) {
      parentPos[i] -= margin[i]
      parentSize[i] += 2 * margin[i]
    }

  let screenBorders = params?.screenBorders ?? ["@bw", "@bh"]
  let bw = toPixels(guiScene, screenBorders[0])
  let bh = toPixels(guiScene, screenBorders[1])
  let screenStart = [bw, bh]
  let screenEnd   = [screen_width().tointeger() - bw, screen_height().tointeger() - bh]

  let checkAligns = checkAlignsMap?[defAlign] ?? checkAlignsMap.def

  foreach (checkIdx, align in checkAligns) {
    let isAlignForced = checkIdx == checkAligns.len() - 1

    let {isVertical = true, isPositive = true } = vertPosMap?[align]

    let axis = isVertical ? 1 : 0
    let parentTargetPoint = [0.5, 0.5] 
    let frameOffset = [0 - menuSize[0] / 2, 0 - menuSize[1] / 2]
    let frameOffsetText = ["-w/2", "-h/2"] 

    if (isPositive) {
      parentTargetPoint[axis] = 1.0
      frameOffset[axis] = 0
      frameOffsetText[axis] = ""
    }
    else {
      parentTargetPoint[axis] = 0.0
      frameOffset[axis] = 0 - menuSize[isVertical ? 1 : 0]
      frameOffsetText[axis] = isVertical ? "-h" : "-w"
    }

    let targetPoint = [
      parentPos[0] + (parentSize[0] * (params?.customPosX ?? parentTargetPoint[0])).tointeger()
      parentPos[1] + (parentSize[1] * (params?.customPosY ?? parentTargetPoint[1])).tointeger()
    ]

    let isFits = [true, true]
    let sideSpace = [0, 0]
    foreach (i, _v in sideSpace) {
      if (i == axis)
        sideSpace[i] = isPositive ? screenEnd[i] - targetPoint[i] : targetPoint[i] - screenStart[i]
      else
        sideSpace[i] = screenEnd[i] - screenStart[i]

      isFits[i] = sideSpace[i] >= menuSize[i]
    }

    if ((!isFits[0] || !isFits[1]) && !isAlignForced)
      continue

    let arrowOffset = [0, 0]
    let menuPos = [targetPoint[0] + frameOffset[0], targetPoint[1] + frameOffset[1]]

    foreach (i, _v in menuPos) {
      if (i == axis && isFits[i])
        continue

      if (menuPos[i] < screenStart[i] || !isFits[i]) {
        arrowOffset[i] = menuPos[i] - screenStart[i]
        menuPos[i] = screenStart[i]
      }
      else if (menuPos[i] + menuSize[i] > screenEnd[i]) {
        arrowOffset[i] = menuPos[i] + menuSize[i] - screenEnd[i]
        menuPos[i] = screenEnd[i] - menuSize[i]
      }
    }

    let menuPosText = ["", ""]
    foreach (i, _v in menuPos)
      menuPosText[i] = (menuPos[i] - frameOffset[i]) + frameOffsetText[i]

    menuObj["menu_align"] = align
    menuObj["pos"] = ", ".join(menuPosText, true)

    if (arrowOffset[0] || arrowOffset[1]) {
      let arrowObj = menuObj.findObject("popup_menu_arrow")
      if (check_obj(arrowObj)) {
        guiScene.setUpdatesEnabled(true, true)
        let arrowPos = arrowObj.getPosRC()
        foreach (i, _v in arrowPos)
          arrowPos[i] += arrowOffset[i]
        arrowObj["style"] = "".concat("position:root; pos:", ", ".join(arrowPos, true), ";")
      }
    }

    return align
  }

  return defAlign
}

let textAreaTagsRegexp = [
  regexp2("</?color[^>]*>")
  regexp2("</?link[^>]*>")
  regexp2("</?b>")
]


function removeTextareaTags(text) {
  foreach (re in textAreaTagsRegexp)
    text = re.replace("", text)
  return text
}

function getObjValidIndex(obj) {
  if (!check_obj(obj))
    return -1

  let value = obj.getValue()
  if (value < 0 || value >= obj.childrenCount())
    return -1

  return value
}

function getObjValue(parentObj, id, defValue = null) {
  if (!check_obj(parentObj))
    return defValue

  let obj = parentObj.findObject(id)
  if (check_obj(obj))
    return obj.getValue()

  return defValue
}

function show_obj(obj, status) {
  if (!check_obj(obj))
    return null

  obj.enable(status)
  obj.show(status)
  return obj
}

function showObjById(id, status, scene = null) {
  let obj = check_obj(scene) ? scene.findObject(id) : get_cur_gui_scene()[id]
  return show_obj(obj, status)
}

function showObjectsByTable(obj, table) {
  if (!check_obj(obj))
    return

  foreach (id, status in table)
    showObjById(id, status, obj)
}

function enableObjsByTable(obj, table) {
  if (!obj?.isValid)
    return

  foreach (id, status in table) {
    let curObj = obj.findObject(id)
    if (curObj?.isValid)
      curObj.enable(status)
  }
}

function activateObjsByTable(obj, table) {
  if (!obj?.isValid)
    return

  foreach (id, status in table) {
    let curObj = obj.findObject(id)
    if (curObj?.isValid)
      curObj.inactiveColor = status ? "no" : "yes"
  }
}

function setFocusToNextObj(scene, objIdsList, increment) {
  let objectsList = objIdsList.map(@(id) id != null ? scene.findObject(id) : null)
    .filter(@(obj) check_obj(obj) && obj.isVisible() && obj.isEnabled())
  let listLen = objectsList.len()
  if (listLen == 0)
    return
  let curIdx = objectsList.findindex(@(obj) obj.isFocused()) ?? (increment >= 0 ? -1 : listLen)
  let newIdx = wrapIdxInArrayLen(curIdx + increment, listLen)
  objectsList[newIdx].select()
}

function getSelectedChild(obj) {
  if (!obj?.isValid())
    return null

  let total = obj.childrenCount()
  if (total == 0)
    return null

  let value = math.clamp(obj.getValue(), 0, total - 1)
  return obj.getChild(value)
}

function findChild(obj, func) {
  let res = { childIdx = -1, childObj = null }
  if (!obj?.isValid())
    return res

  let total = obj.childrenCount()
  for (local i = 0; i < total; ++i) {
    let childObj = obj.getChild(i)
    if (childObj?.isValid() && func(childObj))
      return { childIdx = i, childObj }
  }
  return res
}

let findChildIndex = @(obj, func) findChild(obj, func).childIdx

function color4ToDaguiString(color) {
  return format("%02X%02X%02X%02X",
    math.clamp(255 * color.a, 0, 255),
    math.clamp(255 * color.r, 0, 255),
    math.clamp(255 * color.g, 0, 255),
    math.clamp(255 * color.b, 0, 255))
}

function daguiStringToColor4(colorStr) {
  let res = Color4()
  if (!colorStr.len())
    return res

  if (colorStr.slice(0, 1) == "#")
    colorStr = colorStr.slice(1)
  if (colorStr.len() != 8 && colorStr.len() != 6)
    return res

  let colorInt = hexStringToInt(colorStr)
  if (colorStr.len() == 8)
    res.a = ((colorInt & 0xFF000000) >> 24).tofloat() / 255
  res.r = ((colorInt & 0xFF0000) >> 16).tofloat() / 255
  res.g = ((colorInt & 0xFF00) >> 8).tofloat() / 255
  res.b = (colorInt & 0xFF).tofloat() / 255
  return res
}

function multiplyDaguiColorStr(colorStr, multiplier) {
  return color4ToDaguiString(daguiStringToColor4(colorStr) * multiplier)
}

function getDaguiObjAabb(obj) {
  if (!obj?.isValid())
    return null

  let size = obj.getSize()
  if (size[0] < 0)
    return null 

  return {
    size
    pos = obj.getPosRC()
    visible = obj.isVisible()
  }
}

function move_mouse_on_obj(obj) { 
  if (obj?.isValid())
    obj.setMouseCursorOnObject()
}

function move_mouse_on_child(obj, idx = 0) { 
  if (is_mouse_last_time_used() || !obj?.isValid() || obj.childrenCount() <= idx || idx < 0)
    return
  let child = obj.getChild(idx)
  if (!child.isValid())
    return
  child.scrollToView()
  get_cur_gui_scene().performDelayed({}, function() {
    if (!child?.isValid())
      return
    child.setMouseCursorOnObject()
  })
}

function move_mouse_on_child_by_value(obj) { 
  if (obj?.isValid())
    move_mouse_on_child(obj, obj.getValue())
}

function select_editbox(obj) {
  if (!obj?.isValid())
    return
  if (is_mouse_last_time_used())
    obj.select()
  else
    obj.setMouseCursorOnObject()
}

return {
  setFocusToNextObj
  getSelectedChild
  findChildIndex
  findChild
  check_obj
  show_obj
  showObjById
  showObjectsByTable
  enableObjsByTable
  activateObjsByTable
  getObjValue
  getObjValidIndex
  setObjPosition
  setPopupMenuPosAndAlign
  adjustWindowSize
  adjustWindowSizeByConfig
  countSizeInItems
  toPixels
  removeTextareaTags
  color4ToDaguiString
  multiplyDaguiColorStr
  getDaguiObjAabb
  move_mouse_on_obj
  move_mouse_on_child
  move_mouse_on_child_by_value
  select_editbox

  ALIGN
}
