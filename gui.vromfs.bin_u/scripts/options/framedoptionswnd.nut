//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")

gui_handlers.FramedOptionsWnd <- class (gui_handlers.GenericOptions) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/framedOptionsWnd.blk"
  sceneNavBlkName = null
  multipleInstances = true

  align = ALIGN.TOP
  alignObj = null
  menuWidth = "0.6@sf"

  function initScreen() {
    let tableObj = this.scene.findObject("optionslist")
    tableObj.width = this.menuWidth
    if (this.options) {
      tableObj.height = this.options.len() + "@baseTrHeight"
      if (this.options.len() <= 1)
        tableObj.invisibleSelection = "yes"
    }

    base.initScreen()

    this.align = setPopupMenuPosAndAlign(this.alignObj, this.align, this.scene.findObject("main_frame"))
    this.initOpenAnimParams()
  }

  function goBack() {
    this.applyOptions(true)
  }

  function applyReturn() {
    if (!this.applyFunc)
      this.restoreMainOptions()
    base.applyReturn()
  }

  function initOpenAnimParams() {
    let animObj = this.scene.findObject("anim_block")
    if (!animObj)
      return
    let size = animObj.getSize()
    if (!size[0] || !size[1])
      return

    let isVertical = this.align == ALIGN.TOP || this.align == ALIGN.BOTTOM
    let scaleId = isVertical ? "height" : "width"
    let scaleAxis = isVertical ? 1 : 0

    animObj[scaleId] = "1"
    animObj[scaleId + "-base"] = "1"
    animObj[scaleId + "-end"] = size[scaleAxis].tostring()
  }
}
