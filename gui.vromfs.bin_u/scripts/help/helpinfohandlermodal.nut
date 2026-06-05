from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getBlockFromObjData, createHighlight } = require("%scripts/guiBox.nut")
let { getLinkLinesMarkup } = require("%scripts/linesGenerator.nut")
let { findPlaceForHintByRect } = require("%globalScripts/guiGeom/hintPlacement.nut")






                  






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

function findPlaceForHint(itemObj, rects, hintSizes, safeAreaRect) {
  if (!itemObj?.isValid())
    return null
  let [ x, y ] = itemObj.getPos()
  let [ w, h ] = itemObj.getSize()
  let itemRect = { x, y, w, h }
  let hintSize = { w = hintSizes.hintWidth, h = hintSizes.hintHeight }
  return findPlaceForHintByRect(itemRect, rects, hintSize, hintSizes.padding, safeAreaRect)
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

    
    let highlightList = []
    foreach (idx, link in links) {
      let objBlock = getBlockFromObjData(link.obj, this.objContainer)

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

    this.guiScene.setUpdatesEnabled(true, true) 

    createHighlight(this.scene.findObject("dark_screen"), highlightList, this, { onClick = "goBack" })

    let linesData = getLinkLinesMarkup(this.getLinesGeneratorConfig())
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