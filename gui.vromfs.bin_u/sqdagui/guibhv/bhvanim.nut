::create_ObjMoveToOBj <- function create_ObjMoveToOBj(scene, objStart, objTarget, config = null)
  //createBlk == null -> create objTarget clone
{
  if (!::check_obj(scene) || !::check_obj(objStart) || !::check_obj(objTarget))
    return

  local handlerClass = class {
    onFinishMove = (@(objTarget) function (obj) {
      if (::check_obj(objTarget))
        objTarget.show(true)
    })(objTarget)
  }
  local handlerObj = handlerClass()

  local guiScene = ::get_gui_scene()
  local moveObj = guiScene.createElementByObject(scene, "gui/moveToObj.blk", "tdiv", handlerObj)
  local bhvFuncName = config?.bhvFunc ?? "cube"
  moveObj["pos-func"] = bhvFuncName
  local sizeObj = moveObj.findObject("size-part")
  sizeObj["size-func"] = bhvFuncName
  if (config && ("createBlk" in config))
    guiScene.replaceContent(sizeObj, config.createBlk, handlerObj)
  else
  {
    local cloneObj = objTarget.getClone(sizeObj, handlerObj)
    cloneObj.pos = "0,0"
    cloneObj.size = "pw, ph"
  }
  objTarget.show(config?.isTargetVisible ?? false)

  local startPos = objStart.getPosRC()
  local tarPos = objTarget.getPosRC()
  moveObj.left = startPos[0].tostring()
  moveObj["left-base"] = startPos[0].tostring()
  moveObj["left-end"] = tarPos[0].tostring()
  moveObj.top = startPos[1].tostring()
  moveObj["top-base"] = startPos[1].tostring()
  moveObj["top-end"] = tarPos[1].tostring()

  local startSize = objStart.getSize()
  local tarSize = objTarget.getSize()
  sizeObj.width = startSize[0].tostring()
  sizeObj["width-base"] = startSize[0].tostring()
  sizeObj["width-end"] = tarSize[0].tostring()
  sizeObj.height = startSize[1].tostring()
  sizeObj["height-base"] = startSize[1].tostring()
  sizeObj["height-end"] = tarSize[1].tostring()

  if (config && ("time" in config))
  {
    local timeTxt = (config.time * 1000).tointeger().tostring()
    moveObj["pos-time"] = timeTxt
    sizeObj["size-time"] = timeTxt
  }
}
