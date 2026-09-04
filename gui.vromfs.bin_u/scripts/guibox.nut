from "string" import format
from "%scripts/dagui_library.nut" import *
from "types" import String, Function, Array, Table

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let BaseGuiBox = require("%globalScripts/guiGeom/guiBox.nut").GuiBox

let GuiBox = class (BaseGuiBox) {
  function setFromDaguiObj(obj) {
    let size = obj.getSize()
    let pos = obj.getPosRC()
    this.c1 = [pos[0], pos[1]]
    this.c2 = [pos[0] + size[0], pos[1] + size[1]]
    return this
  }
}

let getBoxBlkText = @(box, tag)
  format("%s { size:t='%d, %d'; pos:t='%d, %d'; position:t='absolute' } ",
    tag, box.c2[0] - box.c1[0], box.c2[1] - box.c1[1], box.c1[0], box.c1[1])

function blockToView(block) {
  let box = block.box
  for (local i = 0; i < 2; i++) {
    block[$"pos{i}"] <- box.c1[i]
    block[$"size{i}"] <- box.c2[i] - box.c1[i]
  }
  return block
}



const _isNoDelayOnClick = false 

function getBlockFromObjData(objData, scene = null, defOnClick = null, defOnDrag = null) {
  local res = null
  local obj = objData
  if (obj instanceof DaGuiObject) {
    if (!obj.isValid())
      return null
  }
  else
    obj = objData?.obj ?? objData

  if (obj instanceof String)
    obj = checkObj(scene) ? scene.findObject(obj) : null
  else if (obj instanceof Function)
    obj = obj()
  if (obj instanceof Array) {
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
  else if (obj instanceof Table) {
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
const _sizeIncAdd = -2 

function createHighlight(scene, objDataArray, handler = null, params = null) {
  
  
                     
                     
                     
  
  
  
  let guiScene = scene.getScene()
  let sizeIncMul = (params?.sizeIncMul ?? _sizeIncMul)
  let sizeIncAdd = (params?.sizeIncAdd ?? _sizeIncAdd)
  let isFullscreen = params?.isFullscreen ?? _isFullscreen
  let rootBox = GuiBox().setFromDaguiObj(isFullscreen ? guiScene.getRoot() : scene)
  let rootPosCompensation = [ -rootBox.c1[0], -rootBox.c1[1] ]
  let defOnClick = params?.onClick
  let view = {
    id = (params?.id ?? _id)
    isFullscreen = isFullscreen
    lightBlock = (params?.lightBlock ?? _lightBlock)
    darkBlock = (params?.darkBlock ?? _darkBlock)
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
    block.onClick <- block?.onClick || defOnClick
    block.onDragStart <- block?.onDragStart
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
  getBoxBlkText
}