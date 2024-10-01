//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

//wndInfoConfig = {
//  textsBlk - blk with texts for this window
//  links = [
//    {
//      obj     - object (or object id) to view (required)
                  //invisible object dont be highlighted, and linked messages to them will be hidden.
//      msgId   - message id in scene textsBlk to link with this object (optional)
//      highlight = true    - need especially highlight this object or not (optional default = true)
//    }
//  ]
//}

function updateHintPosition( mainScene, helpScene, params) {
  let hintObj = helpScene.findObject(params.hintName)
  if (hintObj?.isValid()) {
    let obj = mainScene.findObject(params.objName)
    if (obj?.isValid()) {
      let objPos = obj.getPos()
      let objSize = (params?.sizeMults) ? obj.getSize() : [0,0]
      let sizeMults = params?.sizeMults ?? [0,0]
      let posX = params?.shiftX ? $"{objPos[0] + sizeMults[0]*objSize[0]} {params.shiftX}" : params?.posX ?? 0
      let posY = params?.shiftY ? $"{objPos[1] + sizeMults[1]*objSize[1]} {params.shiftY}" : params?.posY ?? 0
      hintObj.pos = $"{posX}, {posY}"
    }
  }
}

let isIntersectRect = @( a, b ) ( a.y < b.y + b.h && a.y + a.h > b.y && a.x < b.x + b.w && a.x + a.w > b.x)
let isRectAInRectB = @( a, b ) ( a.y > b.y && a.y + a.h < b.y + b.h && a.x > b.x && a.x + a.w < b.x + b.w)

function hasFreePlace (rectsArr, rect, safeAreaRect = null) {
  if (safeAreaRect && !isRectAInRectB( rect, safeAreaRect))
    return false

  foreach ( r in rectsArr) {
    if (isIntersectRect(r, rect))
      return false
  }
  return true
}

function findPlaceForHint(itemObj, rects, hintSizes, safeAreaRect) {
  if (!itemObj?.isValid())
    return null

  let itemPos = itemObj.getPos()
  let itemSize = itemObj.getSize()
  let itemRect = {x = itemPos[0], y = itemPos[1], w = itemSize[0], h = itemSize[1]}
  if (!hasFreePlace(rects, itemRect))
    return null

  let padding = hintSizes.padding
  let hintHeight = hintSizes.hintHeight
  let hintWidth = hintSizes.hintWidth

  let rectsForTest = [
    { x = itemPos[0] + itemSize[0] + padding, y = itemPos[1], w = hintWidth, h = hintHeight}
    { x = itemPos[0] + itemSize[0] + padding, y = itemPos[1] + itemSize[1] - hintHeight, w = hintWidth, h = hintHeight}
    { x = itemPos[0], y = itemPos[1] + itemSize[1] + padding, w = hintWidth, h = hintHeight}
    { x = itemPos[0], y = itemPos[1] - padding - hintHeight, w = hintWidth, h = hintHeight}
    { x = itemPos[0] + itemSize[0] - hintWidth, y = itemPos[1] + itemSize[1] + padding, w = hintWidth, h = hintHeight}
    { x = itemPos[0] + itemSize[0] - hintWidth, y = itemPos[1] - padding - hintHeight, w = hintWidth, h = hintHeight}
  ]

  foreach (hintRect in rectsForTest) {
    if (hasFreePlace(rects, hintRect, safeAreaRect)) {
      rects.append(itemRect)
      rects.append(hintRect)
      return hintRect
    }
  }
  return null
}

gui_handlers.HelpInfoHandlerModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/tutorials/tutorWnd.blk"
  config = null
  ownerScene = null
  objContainer = null
  handlerHelpCaller = null

  static function openHelp(handler) {
    gui_handlers.HelpInfoHandlerModal.open(handler.getWndHelpConfig(), handler.scene, handler)
  }

  static function open(wndInfoConfig, wndScene, handlerHelpCaller = null) {
    if (!wndInfoConfig)
      return

    let params = {
      config = wndInfoConfig
      ownerScene = wndScene
      handlerHelpCaller = handlerHelpCaller?.weakref()
    }
    return handlersManager.loadHandler(gui_handlers.HelpInfoHandlerModal, params)
  }

  function initScreen() {
    if (!this.config)
      return this.goBack()

    this.objContainer = getTblValue("objContainer", this.config, this.ownerScene)
    if (!checkObj(this.objContainer))
      return this.goBack()

    let links = getTblValue("links", this.config)
    if (!links)
      return this.goBack()

    let textsBlk = this.config?.textsBlk
    if (textsBlk)
      this.guiScene.replaceContent(this.scene.findObject("texts_screen"), textsBlk, null)

    if (this.handlerHelpCaller?.prepareHelpPage != null) {
      this.handlerHelpCaller.prepareHelpPage(this)
      this.guiScene.applyPendingChanges(false)
    }

    //update messages visibility to correct update other messages positions
    let highlightList = []
    foreach (idx, link in links) {
      let objBlock = ::guiTutor.getBlockFromObjData(link.obj, this.objContainer)

      if (!link?.msgId)
        link.msgId <- null

      let msgObj = link.msgId ? this.scene.findObject(link.msgId) : null
      if (checkObj(msgObj)) {
        msgObj.show(!!objBlock)
        if ("text" in link)
          msgObj.setValue(link.text)
      }
      if (objBlock && (link?.highlight ?? true))
        highlightList.append(objBlock.__merge({ id = $"lightObj_{idx}" }))
    }

    this.guiScene.setUpdatesEnabled(true, true) //need to recount sizes and positions

    ::guiTutor.createHighlight(this.scene.findObject("dark_screen"), highlightList, this, { onClick = "goBack" })

    let linesData = ::LinesGenerator.getLinkLinesMarkup(this.getLinesGeneratorConfig())
    this.guiScene.replaceContentFromText(this.scene.findObject("lines_block"), linesData, linesData.len(), this)
  }


  getLinesGeneratorConfig = @() {
    startObjContainer = this.scene
    endObjContainer = this.objContainer
    lineInterval = this.config?.lineInterval
    links = u.keysReplace(this.config.links, { msgId = "start", obj = "end" })
  }

  function consoleNext() {
    this.goBack()
  }
}

return {
  findPlaceForHint
  updateHintPosition
}