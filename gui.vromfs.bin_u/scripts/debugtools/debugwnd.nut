from "%scripts/dagui_natives.nut" import get_file_modify_time_sec, is_existing_file
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { read_text_from_file } = require("dagor.fs")
let loadTemplateText = memoize(@(v) read_text_from_file(v))

gui_handlers.debugWndHandler <- class (BaseGuiHandler) {
  sceneBlkName = "%gui/debugFrame.blk"
  wndType = handlerType.MODAL

  isExist = false
  blkName = null
  tplName = null
  tplParams = {}
  lastModified = -1
  checkTimer = 0.0

  callbacksContext = null

  function initScreen() {
    this.isExist = this.blkName ? is_existing_file(this.blkName, false) : false
    this.tplName = (this.blkName ?? "").endswith(".tpl") ? this.blkName : null
    this.tplParams = this.tplParams || {}

    this.scene.findObject("debug_wnd_update").setUserData(this)
    this.updateWindow()
  }

  function reinitScreen(params) {
    let _blkName = getTblValue("blkName", params, this.blkName)
    let _tplParams = getTblValue("tplParams", params, this.tplParams)
    if (_blkName == this.blkName && u.isEqual(_tplParams, this.tplParams))
      return

    this.blkName = _blkName
    this.isExist = this.blkName ? is_existing_file(this.blkName, false) : false
    this.tplName = (this.blkName ?? "").endswith(".tpl") ? this.blkName : null
    this.tplParams = _tplParams || {}

    this.lastModified = -1
    this.updateWindow()
  }

  function updateWindow() {
    if (!checkObj(this.scene))
      return

    let obj = this.scene.findObject("debug_wnd_content_box")
    if (!this.isExist) {
      let ptxt = this.blkName == null ? "No file specified." :
          "".concat("File not found: \"", colorize("userlogColoredText", this.blkName), "\"")
      let txt = "".concat(ptxt
          ,"~nUsage examples:"
          ,"~ndebug_wnd(\"%gui/debriefing/debriefing.blk\")"
          ,"~ndebug_wnd(\"%gui/menuButton.tpl\", {buttonText=\"Test\"})") // warning disable: -forgot-subst
      let data = "".concat("textAreaCentered { pos:t='pw/2-w/2, ph/2-h/2' position:t='absolute' text='", txt, "' }")
      return this.guiScene.replaceContentFromText(obj, data, data.len(), this.callbacksContext)
    }

    if (this.tplName) {
      let data = handyman.render(loadTemplateText(this.tplName), this.tplParams)
      this.guiScene.replaceContentFromText(obj, data, data.len(), this.callbacksContext)
    }
    else
      this.guiScene.replaceContent(obj, this.blkName, this.callbacksContext)

    if ("onCreate" in this.callbacksContext)
      this.callbacksContext.onCreate(obj)
  }

  function checkModify() {
    if (!this.isExist)
      return
    let modified = get_file_modify_time_sec(this.blkName)
    if (modified < 0)
      return

    if (this.lastModified < 0) {
      this.lastModified = modified
      return
    }

    if (this.lastModified != modified) {
      this.lastModified = modified
      this.updateWindow()
    }
  }

  function onUpdate(_obj, dt) {
    this.checkTimer -= dt
    if (this.checkTimer < 0) {
      this.checkTimer += 0.5
      this.checkModify()
    }
  }
}

function debugWnd(blkName = null, tplParams = {}, callbacksContext = null) {
  handlersManager.loadHandler(gui_handlers.debugWndHandler,
    { blkName = blkName, tplParams = tplParams, callbacksContext = callbacksContext })
}

return debugWnd
