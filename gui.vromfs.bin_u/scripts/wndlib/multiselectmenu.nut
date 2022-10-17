from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

/*
  config = {
    onChangeValueCb = function(selValuesArray)   //callback on each value change
    onChangeValuesBitMaskCb = function(selBitMask)   //callback on each value change
    onFinalApplyCb = function(selValuesArray)   //callback on close window if values was changed
    onFinalApplyBitMaskCb = function(selBitMask)   //callback on close window if values was changed

    align = "top"/"bottom"/"left"/"right"
    alignObj = DaguiObj  //object to align menu

    list = [ //max-len 32
      {
        text = string
        icon = string
        selected = boolean
        show = boolean || function
        value = ...    //only required when use not bitMask callbacks
      }
      ...
    ]
  }
*/
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_start_multi_select_menu <- function gui_start_multi_select_menu(config)
{
  ::handlersManager.loadHandler(::gui_handlers.MultiSelectMenu, config)
}

::gui_handlers.MultiSelectMenu <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/multiSelectMenu"
  needVoiceChat = false

  list = null
  align = "top"
  alignObj = null

  onChangeValueCb = null
  onChangeValuesBitMaskCb = null
  onFinalApplyCb = null
  onFinalApplyBitMaskCb = null

  initialBitMask = 0
  currentBitMask = 0
  sndSwitchOn = null
  sndSwitchOff = null

  function getSceneTplView()
  {
    initListValues()

    return {
      list = list || []
      value = currentBitMask
      sndSwitchOn = sndSwitchOn
      sndSwitchOff = sndSwitchOff
    }
  }

  function initScreen()
  {
    if (!list)
      return goBack()

    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))
    guiScene.applyPendingChanges(false)
    ::move_mouse_on_child(scene.findObject("multi_select"), 0)
  }

  function initListValues()
  {
    if (!list)
      return

    local mask = 0
    foreach(idx, option in list)
    {
      option.show <- getTblValue("show", option, true)
      mask = stdMath.change_bit(mask, idx, getTblValue("selected", option))
    }

    initialBitMask = mask
    currentBitMask = mask
  }

  function getCurValuesArray()
  {
    let selOptions = ::get_array_by_bit_value(currentBitMask, list)
    return ::u.map(selOptions, function(o) { return getTblValue("value", o) })
  }

  function onChangeValue(obj)
  {
    currentBitMask = obj.getValue()
    if (onChangeValuesBitMaskCb)
      onChangeValuesBitMaskCb(currentBitMask)
    if (onChangeValueCb)
      onChangeValueCb(getCurValuesArray())
  }

  function close()
  {
    goBack()

    if (currentBitMask == initialBitMask)
      return

    if (onFinalApplyBitMaskCb)
      onFinalApplyBitMaskCb(currentBitMask)
    if (onFinalApplyCb)
      onFinalApplyCb(getCurValuesArray())
  }
}
