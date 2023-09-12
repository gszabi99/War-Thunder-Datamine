//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")


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

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.HelpInfoHandlerModal <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/tutorials/tutorWnd.blk"

  config = null
  ownerScene = null

  objContainer = null

  static function openHelp(handler) {
    gui_handlers.HelpInfoHandlerModal.open(handler.getWndHelpConfig(), handler.scene)
  }

  static function open(wndInfoConfig, wndScene) {
    if (!wndInfoConfig)
      return

    let params = {
      config = wndInfoConfig
      ownerScene = wndScene
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
        highlightList.append(objBlock.__merge({ id = "lightObj_" + idx }))
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