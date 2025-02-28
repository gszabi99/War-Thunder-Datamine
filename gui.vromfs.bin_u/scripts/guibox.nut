from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { Point2 } = require("dagor.math")
let { format } = require("string")

/* guiBox API
  isIntersect(box)      - (bool) return true if box intersect current

  addBox(box)           - modify current box to minimal size which contains both boxes
  cutBox(boxToCutFrom)  - return array of boxes which fill full empty space of boxToCutFrom not intersect with current
                          return null when no intersections with boxToCutFrom
                          return empty array when boxToCutFrom completely inside current box

  incSize(kAdd, kMul)   - increase box size around
  setFromDaguiObj(obj)  - set size and pos from dagui object params
  cloneBox(incSize = 0) - clones box. can increase new box size when incSize != 0
  getBlkText(tag)       - generate text with this tag for replaceContentFromText in guiScene
*/

local GuiBox
GuiBox = class {
  c1 = null  //[x1, y1]
  c2 = null  //[x2, y2]
  priority = 0
  isToStringForDebug = true

  constructor(vx1 = 0, vy1 = 0, vx2 = 0, vy2 = 0, vpriority = 0) {
    this.c1 = [vx1, vy1]
    this.c2 = [vx2, vy2]
    this.priority = vpriority
  }

  function setFromDaguiObj(obj) {
    let size = obj.getSize()
    let pos = obj.getPosRC()
    this.c1 = [pos[0], pos[1]]
    this.c2 = [pos[0] + size[0], pos[1] + size[1]]
    return this
  }

  function addBox(box) {
    for (local i = 0; i < 2; i++) {
      if (box.c1[i] < this.c1[i])
        this.c1[i] = box.c1[i]
      if (box.c2[i] > this.c2[i])
        this.c2[i] = box.c2[i]
    }
  }

  function _tostring() {
    return format("GuiBox((%d,%d), (%d,%d)%s)", this.c1[0], this.c1[1], this.c2[0], this.c2[1],
      this.priority ? ($", priority = {this.priority}") : "")
  }

  function isIntersect(box) {
    return  !(box.c1[0] >= this.c2[0] || this.c1[0] >= box.c2[0]
           || box.c1[1] >= this.c2[1] || this.c1[1] >= box.c2[1])
  }

  function isInside(box) {
    return   (box.c1[0] <= this.c1[0] && this.c2[0] <= box.c2[0]
           && box.c1[1] <= this.c1[1] && this.c2[1] <= box.c2[1])
  }

  function getIntersectCorner(box) {
    if (!this.isIntersect(box))
      return null

    return Point2((box.c2[0] > this.c1[0]) ? this.c1[0] : this.c2[0],
                    (box.c2[1] > this.c1[1]) ? this.c1[1] : this.c2[1])
  }

  function cutBox(box) { //return array of boxes cutted from box
    if (!this.isIntersect(box))
      return null

    let cutList = []
    if (box.c1[0] < this.c1[0])
      cutList.append(GuiBox(box.c1[0], box.c1[1], this.c1[0], box.c2[1]))
    if (box.c2[0] > this.c2[0])
      cutList.append(GuiBox(this.c2[0], box.c1[1], box.c2[0], box.c2[1]))

    let offset1 = max(this.c1[0], box.c1[0])
    let offset2 = min(this.c2[0], box.c2[0])
    if (box.c1[1] < this.c1[1])
      cutList.append(GuiBox(offset1, box.c1[1], offset2, this.c1[1]))
    if (box.c2[1] > this.c2[1])
      cutList.append(GuiBox(offset1, this.c2[1], offset2, box.c2[1]))

    return cutList
  }

  function incPos(inc) {
    for (local i = 0; i < 2; i++) {
      this.c1[i] += inc[i]
      this.c2[i] += inc[i]
    }
    return this
  }

  function incSize(kAdd, kMul = 0) {
    for (local i = 0; i < 2; i++) {
      local inc = kAdd
      if (kMul)
        inc += ((this.c2[i] - this.c1[i]) * kMul).tointeger()
      if (inc) {
        this.c1[i] -= inc
        this.c2[i] += inc
      }
    }
    return this
  }

  function cloneBox(incSzX = 0, incSzY = null) {
    incSzY = incSzY ?? incSzX
    return GuiBox(this.c1[0] - incSzX, this.c1[1] - incSzY, this.c2[0] + incSzX, this.c2[1] + incSzY)
  }

  function getBlkText(tag) {
    return format("%s { size:t='%d, %d'; pos:t='%d, %d'; position:t='absolute' } ", tag, this.c2[0] - this.c1[0], this.c2[1] - this.c1[1], this.c1[0], this.c1[1])
  }
}

function blockToView(block) {
  let box = block.box
  for (local i = 0; i < 2; i++) {
    block[$"pos{i}"] <- box.c1[i]
    block[$"size{i}"] <- box.c2[i] - box.c1[i]
  }
  return block
}



const _isNoDelayOnClick = false //optional no delay on_click for lightboxes

local getBlockFromObjData

getBlockFromObjData = function(objData, scene = null, defOnClick = null, defOnDrag = null) {
  local res = null
  local obj = objData?.obj ?? objData
  if (type(obj) == "string")
    obj = checkObj(scene) ? scene.findObject(obj) : null
  else if (type(obj) == "function")
    obj = obj()
  if (type(obj) == "array") {
    for (local i = 0; i < obj.len(); i++) {
      let block = getBlockFromObjData(obj[i], scene)
      if (!block)
        continue
      if (!res)
        res = block
      else
        res.box.addBox(block.box)
    }
  }
  else if (type(obj) == "table") {
    if (("box" in obj) && obj.box)
      res = clone obj
  }
  else if (type(obj) == "instance")
    if (obj instanceof DaGuiObject) {
      if (checkObj(obj) && obj.isVisible())
        res = {
          id = $"_{obj?.id ?? "null"}"
          box = GuiBox().setFromDaguiObj(obj)
        }
    }
    else if (obj instanceof GuiBox)
      res = {
        id = ""
        box = obj
      }
  if (!res)
    return null

  let id = objData?.id
  if (id)
    res.id <- id
  res.onClick <- objData?.onClick ?? defOnClick
  res.onDragStart <-objData?.onDragStart ?? defOnDrag
  res.isNoDelayOnClick <- objData?.isNoDelayOnClick ?? _isNoDelayOnClick
  res.hasArrow <- objData?.hasArrow ?? false
  return res
}


const _id = "tutor_screen_root"
const _lightBlock = "tutorLight"
const _darkBlock = "tutorDark"
const _isFullscreen = true
const _sizeIncMul = 0
const _sizeIncAdd = -2 //boxes size decreased for more accurate view of close objects

function createHighlight(scene, objDataArray, handler = null, params = null) {
  //obj Config = [{
  //    obj          //    DaGuiObject,
                     // or string obj name in scene,
                     // or table with size and pos,
                     // or array of objects to highlight as one
  //    box          // GuiBox - can be used instead of obj
  //    id, onClick
  //  }...]
  let guiScene = scene.getScene()
  let sizeIncMul = getTblValue("sizeIncMul", params, _sizeIncMul)
  let sizeIncAdd = getTblValue("sizeIncAdd", params, _sizeIncAdd)
  let isFullscreen = params?.isFullscreen ?? _isFullscreen
  let rootBox = GuiBox().setFromDaguiObj(isFullscreen ? guiScene.getRoot() : scene)
  let rootPosCompensation = [ -rootBox.c1[0], -rootBox.c1[1] ]
  let defOnClick = getTblValue("onClick", params, null)
  let view = {
    id = getTblValue("id", params, _id)
    isFullscreen = isFullscreen
    lightBlock = getTblValue("lightBlock", params, _lightBlock)
    darkBlock = getTblValue("darkBlock", params, _darkBlock)
    lightBlocks = []
    darkBlocks = []
  }

  let rootXPad = isFullscreen ? -to_pixels("1@bwInVr") : 0
  let rootYPad = isFullscreen ? -to_pixels("1@bhInVr") : 0
  let darkBoxes = []
  if (view.darkBlock && view.darkBlock != "")
    darkBoxes.append(rootBox.cloneBox(rootXPad, rootYPad).incPos(rootPosCompensation))

  foreach (config in objDataArray) {
    let block = getBlockFromObjData(config, scene, defOnClick)
    if (!block)
      continue

    block.box.incSize(sizeIncAdd, sizeIncMul)
    block.box.incPos(rootPosCompensation)
    block.onClick <- getTblValue("onClick", block) || defOnClick
    block.onDragStart <- getTblValue("onDragStart", block)
    view.lightBlocks.append(blockToView(block))

    for (local i = darkBoxes.len() - 1; i >= 0; i--) {
      let newBoxes = block.box.cutBox(darkBoxes[i])
      if (!newBoxes)
        continue

      darkBoxes.remove(i)
      darkBoxes.extend(newBoxes)
    }
  }

  foreach (box in darkBoxes)
    view.darkBlocks.append(blockToView({ box = box, onClick = defOnClick }))

  let data = handyman.renderCached(("%gui/tutorials/tutorDarkScreen.tpl"), view)
  guiScene.replaceContentFromText(scene, data, data.len(), handler)

  return scene.findObject(view.id)
}

return {
  GuiBox
  createHighlight
  getBlockFromObjData
}