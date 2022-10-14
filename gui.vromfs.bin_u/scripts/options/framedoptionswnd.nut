from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.FramedOptionsWnd <- class extends ::gui_handlers.GenericOptions {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/framedOptionsWnd.blk"
  sceneNavBlkName = null
  multipleInstances = true

  align = ALIGN.TOP
  alignObj = null
  menuWidth = "0.6@sf"

  function initScreen()
  {
    let tableObj = scene.findObject("optionslist")
    tableObj.width = menuWidth
    if (options)
    {
      tableObj.height = options.len() + "@baseTrHeight"
      if (options.len() <= 1)
        tableObj.invisibleSelection = "yes"
    }

    base.initScreen()

    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))
    initOpenAnimParams()
  }

  function goBack()
  {
    applyOptions(true)
  }

  function applyReturn()
  {
    if (!applyFunc)
      restoreMainOptions()
    base.applyReturn()
  }

  function initOpenAnimParams()
  {
    let animObj = scene.findObject("anim_block")
    if (!animObj)
      return
    let size = animObj.getSize()
    if (!size[0] || !size[1])
      return

    let isVertical = align == ALIGN.TOP || align == ALIGN.BOTTOM
    let scaleId = isVertical ? "height" : "width"
    let scaleAxis = isVertical ? 1 : 0

    animObj[scaleId] = "1"
    animObj[scaleId + "-base"] = "1"
    animObj[scaleId + "-end"] = size[scaleAxis].tostring()
  }
}
