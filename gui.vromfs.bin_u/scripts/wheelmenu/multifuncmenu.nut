local { openMfm, getMfmSectionTitle, getMfmHandler } = require("scripts/wheelmenu/multifuncMenuTools.nut")
local cfg = require("scripts/wheelmenu/multifuncmenuCfg.nut")

//--------------------------------------------------------------------------------------------------

class ::gui_handlers.multifuncMenuHandler extends ::gui_handlers.wheelMenuHandler
{
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
                                 | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                 | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                 | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                                 | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP

  wndControlsAllowMaskWhenInactive = CtrlsInGui.CTRL_ALLOW_FULL

  mfmDescription = null
  curSectionId = null
  path = null

  function initScreen()
  {
    base.initScreen()

    path = path ?? []
    path.append(curSectionId)

    updateCaption()
  }

  function updateCaption()
  {
    local objCaption = scene.findObject("wheel_menu_category")
    local text = getMfmSectionTitle(mfmDescription[curSectionId])
    objCaption.setValue(::colorize("hudGreenTextColor", text))
  }

  function toggleShortcut(shortcutId)
  {
    if (::is_xinput_device())
      switchControlsAllowMask(wndControlsAllowMaskWhenInactive)

    ::emulate_shortcut(shortcutId)

    if (::is_xinput_device() && isActive)
      switchControlsAllowMask(wndControlsAllowMaskWhenActive)
  }

  function gotoPrevMenuOrQuit()
  {
    if (path.len() == 0)
      return

    local escapingSectionId = path.pop()
    mfmDescription[escapingSectionId]?.onExit()

    if (path.len() > 0)
      openMfm(mfmDescription, path.pop(), false)
    else
      quit()
  }

  function gotoSection(sectionId)
  {
    openMfm(mfmDescription, sectionId)
  }

  function quit()
  {
    if (isActive)
    {
      foreach (escapingSectionId in path.reverse())
        mfmDescription[escapingSectionId]?.onExit()
      path.clear()
      showScene(false)
    }
  }
}

//--------------------------------------------------------------------------------------------------

// Called from client
::on_multifunc_menu_request <- function on_multifunc_menu_request(isShow)
{
  if (isShow)
    return openMfm(cfg)
  getMfmHandler()?.quit()
  return true
}

// Called from client
::on_multifunc_menu_item_selected <- function on_multifunc_menu_item_selected(index, isDown) {
  getMfmHandler()?.onShortcutSelectCallback(index, isDown)
  return true
}

// Called from client
::on_multifunc_menu_activate_item <- function on_multifunc_menu_activate_item() {
  getMfmHandler()?.onActivateItemCallback()
  return true
}
