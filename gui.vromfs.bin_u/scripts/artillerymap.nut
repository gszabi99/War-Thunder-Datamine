let { subscribe } = require("eventbus")
let { format } = require("string")
let {
  getArtilleryDispersion = @(x, y) ::artillery_dispersion(x, y), // compatibility with 2.17.0.X
  callArtillery = @(x, y) ::call_artillery(x, y), // compatibility with 2.17.0.X
  onArtilleryClose = @() ::on_artillery_close(), // compatibility with 2.17.0.X
  artilleryCancel = @() ::artillery_cancel(), // compatibility with 2.17.0.X
  getMapRelativePlayerPos = @() ::get_map_relative_player_pos(), // compatibility with 2.17.0.X
  getArtilleryRange = @() ::artillery_range(), // compatibility with 2.17.0.X
} = require_optional("guiArtillery")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getActionBarItems } = ::require_native("hudActionBar")
local { EII_ARTILLERY_TARGET } = ::require_native("hudActionBarConst")

enum POINTING_DEVICE
{
  MOUSE
  TOUCHSCREEN
  JOYSTICK
  GAMEPAD
}

::gui_handlers.ArtilleryMap <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/artilleryMap.blk"
  shouldBlurSceneBg = true
  shouldFadeSceneInVr = true
  shouldOpenCenteredToCameraInVr = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_ARTILLERY |
                         CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD |
                         CtrlsInGui.CTRL_ALLOW_MP_STATISTICS |
                         CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP

  artilleryReady = true
  artilleryEnabled = true
  artilleryEnabledCheckCooldown = 0.3

  mapSizeMeters = -1
  invalidTargetDispersionRadiusMeters = 60

  mapPos  = [0, 0]
  mapSize = [0, 0]
  objTarget = null
  invalidTargetDispersionRadius = 0
  prevShadeRangePos = [-1, -1]

  pointingDevice = null
  isGamepadMouse = false
  canUseShortcuts = true
  shouldMapClickDoApply = true
  mapCoords = null
  watchAxis = []
  stuckAxis = {}
  prevMousePos = [-1, -1]
  isSuperArtillery = false
  superStrikeRadius = 0.0
  iconSuperArtilleryZone = ""
  iconSuperArtilleryTarget = ""

  function initScreen()
  {
    let objMap = scene.findObject("tactical_map")
    if (::checkObj(objMap))
    {
      mapPos  = objMap.getPos()
      mapSize = objMap.getSize()
    }

    objTarget = scene.findObject(isSuperArtillery ? "super_artillery_target" : "artillery_target")
    if (::checkObj(objTarget))
    {
      if (isSuperArtillery)
      {
        objTarget["background-image"] = iconSuperArtilleryZone
        let objTargetCenter = scene.findObject("super_artillery_target_center")
        objTargetCenter["background-image"] = iconSuperArtilleryTarget
      }
    }

    watchAxis = ::joystickInterface.getAxisWatch(false, true)
    isGamepadMouse = ::g_gamepad_cursor_controls.getValue()
    pointingDevice = useTouchscreen ? POINTING_DEVICE.TOUCHSCREEN
      : ::is_xinput_device() && !isGamepadMouse ? POINTING_DEVICE.GAMEPAD
      : POINTING_DEVICE.MOUSE

    canUseShortcuts = !useTouchscreen || ::is_xinput_device()
    shouldMapClickDoApply = !useTouchscreen && !::is_xinput_device()

    ::g_hud_event_manager.subscribe("LocalPlayerDead", function (data) {
      ::close_artillery_map()
    }, this)

    reinitScreen()
  }

  function reinitScreen(params = {})
  {
    setParams(params)

    let isStick = pointingDevice == POINTING_DEVICE.GAMEPAD || pointingDevice == POINTING_DEVICE.JOYSTICK
    prevMousePos = isStick ? ::get_dagui_mouse_cursor_pos() : [-1, -1]
    mapCoords = isStick ? [0.5, 0.5] : null
    stuckAxis = ::joystickInterface.getAxisStuck(watchAxis)

    scene.findObject("update_timer").setUserData(this)
    update(null, 0.0)
    updateShotcutImages()

    setMousePointerInitialPos(scene.findObject("tactical_map"))
  }

  function update(obj = null, dt = 0.0)
  {
    if (!::checkObj(objTarget))
      return

    let prevArtilleryReady = artilleryReady
    checkArtilleryEnabledByTimer(dt)

    local curPointingice = pointingDevice
    let mousePos = ::get_dagui_mouse_cursor_pos()
    let axisData = ::joystickInterface.getAxisData(watchAxis, stuckAxis)
    let joystickData = ::joystickInterface.getMaxDeviatedAxisInfo(axisData)

    if (mousePos[0] != prevMousePos[0] || mousePos[1] != prevMousePos[1])
    {
      curPointingice = useTouchscreen ? POINTING_DEVICE.TOUCHSCREEN : POINTING_DEVICE.MOUSE
      mapCoords = getMouseCursorMapCoords()
    }
    else if (!isGamepadMouse && (joystickData.x || joystickData.y))
    {
      curPointingice = ::is_xinput_device() ? POINTING_DEVICE.GAMEPAD : POINTING_DEVICE.JOYSTICK
      let displasement = ::joystickInterface.getPositionDelta(dt, 3, joystickData)
      let prevMapCoords = mapCoords || [0.5, 0.5]
      mapCoords = [
        clamp(prevMapCoords[0] + displasement[0], 0.0, 1.0),
        clamp(prevMapCoords[1] + displasement[1], 0.0, 1.0)
      ]
    }

    prevMousePos = mousePos
    if (curPointingice != pointingDevice || prevArtilleryReady != artilleryReady)
      pointingDevice = curPointingice

    let show = mapCoords != null
    let disp = mapCoords ? getArtilleryDispersion(mapCoords[0], mapCoords[1]) : -1
    local valid = show && disp >= 0 && artilleryEnabled
    let dispersionRadius = valid ? (isSuperArtillery ? superStrikeRadius / mapSizeMeters : disp) : invalidTargetDispersionRadius
    valid = valid && artilleryReady

    objTarget.show(show)
    if (show)
    {
      let sizePx = ::round(mapSize[0] * dispersionRadius) * 2
      let posX = 1.0 * mapSize[0] * mapCoords[0]
      let posY = 1.0 * mapSize[1] * mapCoords[1]
      objTarget.size = format("%d, %d", sizePx, sizePx)
      objTarget.pos = format("%d-w/2, %d-h/2", posX, posY)
      if (!isSuperArtillery)
        objTarget.enable(valid)
    }

    let objHint = scene.findObject("txt_artillery_hint")
    if (::checkObj(objHint))
    {
      objHint.setValue(::loc(valid ? "artillery_strike/allowed" :
        (artilleryEnabled ?
          (artilleryReady ? "artillery_strike/not_allowed" : "artillery_strike/not_ready") :
          "artillery_strike/crew_lost")))
      objHint.overlayTextColor = valid ? "good" : "bad"
    }

    let objBtnApply = scene.findObject("btn_apply")
    if (::check_obj(objBtnApply))
      objBtnApply.enable(valid)

    updateMapShadeRadius()
  }

  function updateMapShadeRadius()
  {
    local avatarPos = getMapRelativePlayerPos()
    avatarPos = avatarPos.len() == 2 ? avatarPos : [ 0.5, 0.5 ]
    let diameter  = isSuperArtillery ? 3.0 : (::is_in_flight() ? getArtilleryRange() * 2 : 1.0)
    let rangeSize = [ round(mapSize[0] * diameter), round(mapSize[1] * diameter) ]
    let rangePos  = [ round(mapSize[0] * avatarPos[0] - rangeSize[0] / 2), round(mapSize[1] * avatarPos[1] - rangeSize[1] / 2) ]

    if (rangePos[0] == prevShadeRangePos[0] && rangePos[1] == prevShadeRangePos[1])
      return
    prevShadeRangePos = rangePos

    invalidTargetDispersionRadius = invalidTargetDispersionRadiusMeters.tofloat() / mapSizeMeters * diameter

    local obj = scene.findObject("map_shade_center")
    if (!::checkObj(obj))
      return

    obj.size = format("%d, %d", rangeSize[0], rangeSize[1])
    obj.pos  = format("%d, %d", rangePos[0], rangePos[1])

    let gap = {
      t = rangePos[1]
      r = mapSize[0] - rangePos[0] - rangeSize[0]
      b = mapSize[1] - rangePos[1] - rangeSize[1]
      l = rangePos[0]
    }

    obj = scene.findObject("map_shade_t")
    obj.show(gap.t > 0)
    if (::checkObj(obj) && gap.t > 0)
    {
      obj.size = format("%d, %d", mapSize[0], gap.t)
      obj.pos  = format("%d, %d", 0, 0)
    }
    obj = scene.findObject("map_shade_b")
    obj.show(gap.b > 0)
    if (::checkObj(obj) && gap.b > 0)
    {
      obj.size = format("%d, %d", mapSize[0], gap.b)
      obj.pos  = format("%d, %d", 0, rangePos[1] + rangeSize[1])
    }
    obj = scene.findObject("map_shade_l")
    obj.show(gap.l > 0)
    if (::checkObj(obj) && gap.l > 0)
    {
      obj.size = format("%d, %d", gap.l, rangeSize[1])
      obj.pos  = format("%d, %d", 0, rangePos[1])
    }
    obj = scene.findObject("map_shade_r")
    obj.show(gap.r > 0)
    if (::checkObj(obj) && gap.r > 0)
    {
      obj.size = format("%d, %d", gap.r, rangeSize[1])
      obj.pos  = format("%d, %d", rangePos[0] + rangeSize[0], rangePos[1])
    }
  }

  function updateShotcutImages()
  {
    let placeObj = scene.findObject("shortcuts_block")
    if (!::checkObj(placeObj))
      return

    let showShortcuts = [
      {
        title = "hotkeys/ID_SHOOT_ARTILLERY"
        shortcuts = ["ID_SHOOT_ARTILLERY"]
        buttonCb = "onApply"
        buttonExtraMarkup = ::is_dev_version ? "accessKey:t='Enter';" : ""
        buttonId = "btn_apply"
      },
      {
        title = "hotkeys/ID_CHANGE_ARTILLERY_TARGETING_MODE"
        shortcuts = ["ID_CHANGE_ARTILLERY_TARGETING_MODE"]
        buttonCb = "onChangeTargetingMode"
        show = ::get_mission_difficulty_int() != ::DIFFICULTY_HARDCORE && !isSuperArtillery
      },
      {
        title = "mainmenu/btnCancel"
        shortcuts = ["ID_ARTILLERY_CANCEL", "ID_ACTION_BAR_ITEM_5"]
        buttonCb = "goBack"
      },
    ]

    local reqDevice = ::STD_MOUSE_DEVICE_ID
    if (::show_console_buttons || pointingDevice == POINTING_DEVICE.GAMEPAD || pointingDevice == POINTING_DEVICE.JOYSTICK)
      reqDevice = ::JOYSTICK_DEVICE_0_ID
    else if (pointingDevice == POINTING_DEVICE.TOUCHSCREEN)
      reqDevice = ::STD_KEYBOARD_DEVICE_ID

    foreach(idx, info in showShortcuts)
      if (info?.show ?? true)
      {
        let shortcuts = ::get_shortcuts(info.shortcuts)
        local pref = null
        local any = null
        foreach(i, actionShortcuts in shortcuts)
        {
          info.primaryShortcutName <- info.shortcuts[i]
          foreach(shortcut in actionShortcuts)
          {
            any = any || shortcut
            if (::find_in_array(shortcut.dev, reqDevice) >= 0)
            {
              pref = shortcut
              break
            }
          }

          if (pref)
            break
        }

        info.primaryShortcut <- pref || any
      }

    local data = []
    foreach(idx, info in showShortcuts)
      if (info?.show ?? true)
      {
        if (canUseShortcuts)
          data.append(getShortcutFrameForHelp(info.primaryShortcut) +
            format("controlsHelpHint { text:t='#%s' }", info.title))
        else
          data.append(::handyman.renderCached("%gui/commonParts/button", {
            id = info?.buttonId ?? ""
            text = "#" + info.title
            funcName = info.buttonCb
            actionParamsMarkup = info?.buttonExtraMarkup
          }))
      }

    data = ::g_string.implode(data, "controlsHelpHint { text:t='    ' }")
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function onChangeTargetingMode(obj)
  {
    toggleShortcut("ID_CHANGE_ARTILLERY_TARGETING_MODE")
  }

  function getShortcutFrameForHelp(shortcut)
  {
    local data = "";
    if (!shortcut)
      return "text { text-align:t='center'; text:t='---' }"

    let curPreset = ::g_controls_manager.getCurPreset()
    for (local k = 0; k < shortcut.dev.len(); k++)
    {
      let name = ::getLocalizedControlName(curPreset, shortcut.dev[k], shortcut.btn[k]);
      local buttonFrame = format("controlsHelpBtn { text:t='%s'; font:t='%s' }", ::g_string.stripTags(name), (name.len()>2)? "@fontTiny" : "@fontMedium");

      if (shortcut.dev[k] == ::STD_MOUSE_DEVICE_ID)
      {
        let mouseBtnImg = "controlsHelpMouseBtn { background-image:t='#ui/gameuiskin#%s.png'; }"
        if (shortcut.btn[k] == 0)
          buttonFrame = format(mouseBtnImg, "mouse_left");
        else if (shortcut.btn[k] == 1)
          buttonFrame = format(mouseBtnImg, "mouse_right");
        else if (shortcut.btn[k] == 2)
          buttonFrame = format(mouseBtnImg, "mouse_center");
      }

      if (shortcut.dev[k] == ::JOYSTICK_DEVICE_0_ID)
      {
        let btnId = shortcut.btn[k]
        if (gamepadIcons.hasTextureByButtonIdx(btnId))
          buttonFrame = format("controlsHelpJoystickBtn { background-image:t='%s' }",
            gamepadIcons.getTextureByButtonIdx(btnId))
      }

      data += ((k != 0)? "text { pos:t='0,0.5ph-0.5h';position:t='relative';text-align:t='center';text:t='+'}":"") + buttonFrame;
    }

    return data;
  }

  function checkArtilleryEnabledByTimer(dt = 0.0)
  {
    artilleryEnabledCheckCooldown -= dt
    if (artilleryEnabledCheckCooldown > 0)
      return

    let { ready, enabled } = getArtilleryStatus()
    artilleryEnabledCheckCooldown = 0.3
    artilleryEnabled = enabled
    artilleryReady = ready
    if (!enabled)
      doQuitDelayed()
  }

  function getArtilleryStatus()
  {
    let { cooldown = 1 } = getActionBarItems().findvalue(@(i) i.type == EII_ARTILLERY_TARGET)
    return {
      enabled = cooldown != 1
      ready = cooldown == 0
    }
  }

  function getMouseCursorMapCoords()
  {
    local res = ::is_xinput_device() && !isGamepadMouse ? mapCoords : null

    let cursorPos = ::get_dagui_mouse_cursor_pos()
    if (cursorPos[0] >= mapPos[0] && cursorPos[0] <= mapPos[0] + mapSize[0] && cursorPos[1] >= mapPos[1] && cursorPos[1] <= mapPos[1] + mapSize[1])
      res = [
        1.0 * (cursorPos[0] - mapPos[0]) / mapSize[0],
        1.0 * (cursorPos[1] - mapPos[1]) / mapSize[1],
      ]

    return res
  }

  function onArtilleryMapClick()
  {
    mapCoords = getMouseCursorMapCoords()
    // Touchscreens and Dualshock4 touchscreen should use map touch just to select point and see
    // dispersion radius, and then [Apply] button to call artillery.
    if (shouldMapClickDoApply)
      onApply()
  }

  function onOutsideMapClick()
  {
    if (shouldMapClickDoApply)
      goBack()
  }

  function onApplyByShortcut()
  {
    // On touchscreen, shortcut toggles by map touch, when ID_SHOOT_ARTILLERY is set to LMB.
    if (!canUseShortcuts)
      return
    onApply()
  }

  function onApply()
  {
    if (getArtilleryStatus().ready && mapCoords && getArtilleryDispersion(mapCoords[0], mapCoords[1]) >= 0)
    {
      callArtillery(mapCoords[0], mapCoords[1])
      doQuit()
    }
  }

  function goBack()
  {
    if (::is_in_flight())
      artilleryCancel()
    else
      doQuit()
  }

  function doQuit()
  {
    onArtilleryClose()
    if (isSceneActive())
      base.goBack()
  }

  doQuitDelayed = @() guiScene.performDelayed(this, function() {
    if (isValid())
      doQuit()
  })
  onEventCloseArtilleryRequest = @(p) doQuitDelayed()

  function onEventHudTypeSwitched(params)
  {
    ::close_artillery_map()
  }
}

::gui_start_artillery_map <- function gui_start_artillery_map(params = {})
{
  ::handlersManager.loadHandler(::gui_handlers.ArtilleryMap,
  {
    mapSizeMeters = params?.mapSizeMeters ?? 1400
    isSuperArtillery = getTblValue("useCustomSuperArtillery", params, false)
    superStrikeRadius = getTblValue("artilleryStrikeRadius", params, 0.0),
    iconSuperArtilleryZone = "#ui/gameuiskin#" + getTblValue("iconSuperArtilleryZoneName", params, ""),
    iconSuperArtilleryTarget = "#ui/gameuiskin#" + getTblValue("iconSuperArtilleryTargetName", params, "")
  })
}

subscribe("artilleryMapOpen", @(p) ::is_in_flight() ? ::gui_start_artillery_map(p) : null)
subscribe("artilleryMapClose", @(_) ::broadcastEvent("CloseArtilleryRequest"))
subscribe("artilleryCallByShortcut", function(_) {
  let handler = ::handlersManager.getActiveBaseHandler()
  if (handler && (handler instanceof ::gui_handlers.ArtilleryMap))
    handler.onApplyByShortcut()
})

::on_artillery_targeting <- @(p = {}) ::is_in_flight() ? ::gui_start_artillery_map(p) : null // compatibility with 2.17.0.X
::close_artillery_map <- @() ::broadcastEvent("CloseArtilleryRequest") // compatibility with 2.17.0.X
::artillery_call_by_shortcut <- function artillery_call_by_shortcut() { // compatibility with 2.17.0.X
  let handler = ::handlersManager.getActiveBaseHandler()
  if (handler && (handler instanceof ::gui_handlers.ArtilleryMap))
    handler.onApplyByShortcut()
}
