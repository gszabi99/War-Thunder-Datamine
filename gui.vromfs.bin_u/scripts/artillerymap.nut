local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
local { setMousePointerInitialPos } = require("scripts/controls/mousePointerInitialPos.nut")

enum POINTING_DEVICE
{
  MOUSE
  TOUCHSCREEN
  JOYSTICK
  GAMEPAD
}

class ::gui_handlers.ArtilleryMap extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/artilleryMap.blk"
  shouldBlurSceneBg = true
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
    local objMap = scene.findObject("tactical_map")
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
        local objTargetCenter = scene.findObject("super_artillery_target_center")
        objTargetCenter["background-image"] = iconSuperArtilleryTarget
      }
    }

    watchAxis = ::joystickInterface.getAxisWatch(false, true)
    isGamepadMouse = ::g_gamepad_cursor_controls.getValue()
    pointingDevice = ::use_touchscreen ? POINTING_DEVICE.TOUCHSCREEN
      : ::is_xinput_device() && !isGamepadMouse ? POINTING_DEVICE.GAMEPAD
      : POINTING_DEVICE.MOUSE

    canUseShortcuts = !::use_touchscreen || ::is_xinput_device()
    shouldMapClickDoApply = !::use_touchscreen && !::is_xinput_device()

    ::g_hud_event_manager.subscribe("LocalPlayerDead", function (data) {
      ::close_artillery_map()
    }, this)

    reinitScreen()
  }

  function reinitScreen(params = {})
  {
    setParams(params)

    local isStick = pointingDevice == POINTING_DEVICE.GAMEPAD || pointingDevice == POINTING_DEVICE.JOYSTICK
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

    local prevArtilleryReady = artilleryReady
    checkArtilleryEnabledByTimer(dt)

    local curPointingice = pointingDevice
    local mousePos = ::get_dagui_mouse_cursor_pos()
    local axisData = ::joystickInterface.getAxisData(watchAxis, stuckAxis)
    local joystickData = ::joystickInterface.getMaxDeviatedAxisInfo(axisData)

    if (mousePos[0] != prevMousePos[0] || mousePos[1] != prevMousePos[1])
    {
      curPointingice = ::use_touchscreen ? POINTING_DEVICE.TOUCHSCREEN : POINTING_DEVICE.MOUSE
      mapCoords = getMouseCursorMapCoords()
    }
    else if (!isGamepadMouse && (joystickData.x || joystickData.y))
    {
      curPointingice = ::is_xinput_device() ? POINTING_DEVICE.GAMEPAD : POINTING_DEVICE.JOYSTICK
      local displasement = ::joystickInterface.getPositionDelta(dt, 3, joystickData)
      local prevMapCoords = mapCoords || [0.5, 0.5]
      mapCoords = [
        ::clamp(prevMapCoords[0] + displasement[0], 0.0, 1.0),
        ::clamp(prevMapCoords[1] + displasement[1], 0.0, 1.0)
      ]
    }

    prevMousePos = mousePos
    if (curPointingice != pointingDevice || prevArtilleryReady != artilleryReady)
      pointingDevice = curPointingice

    local show = mapCoords != null
    local disp = mapCoords ? ::artillery_dispersion(mapCoords[0], mapCoords[1]) : -1
    local valid = show && disp >= 0 && artilleryEnabled
    local dispersionRadius = valid ? (isSuperArtillery ? superStrikeRadius / mapSizeMeters : disp) : invalidTargetDispersionRadius
    valid = valid && artilleryReady

    objTarget.show(show)
    if (show)
    {
      local sizePx = ::round(mapSize[0] * dispersionRadius) * 2
      local posX = 1.0 * mapSize[0] * mapCoords[0]
      local posY = 1.0 * mapSize[1] * mapCoords[1]
      objTarget.size = ::format("%d, %d", sizePx, sizePx)
      objTarget.pos = ::format("%d-w/2, %d-h/2", posX, posY)
      if (!isSuperArtillery)
        objTarget.enable(valid)
    }

    local objHint = scene.findObject("txt_artillery_hint")
    if (::checkObj(objHint))
    {
      objHint.setValue(::loc(valid ? "artillery_strike/allowed" :
        (artilleryEnabled ?
          (artilleryReady ? "artillery_strike/not_allowed" : "artillery_strike/not_ready") :
          "artillery_strike/crew_lost")))
      objHint.overlayTextColor = valid ? "good" : "bad"
    }

    local objBtnApply = scene.findObject("btn_apply")
    if (::check_obj(objBtnApply))
      objBtnApply.enable(valid)

    updateMapShadeRadius()
  }

  function updateMapShadeRadius()
  {
    local avatarPos = ::get_map_relative_player_pos()
    avatarPos = avatarPos.len() == 2 ? avatarPos : [ 0.5, 0.5 ]
    local diameter  = isSuperArtillery ? 3.0 : (::is_in_flight() ? ::artillery_range() * 2 : 1.0)
    local rangeSize = [ round(mapSize[0] * diameter), round(mapSize[1] * diameter) ]
    local rangePos  = [ round(mapSize[0] * avatarPos[0] - rangeSize[0] / 2), round(mapSize[1] * avatarPos[1] - rangeSize[1] / 2) ]

    if (rangePos[0] == prevShadeRangePos[0] && rangePos[1] == prevShadeRangePos[1])
      return
    prevShadeRangePos = rangePos

    invalidTargetDispersionRadius = invalidTargetDispersionRadiusMeters.tofloat() / mapSizeMeters * diameter

    local obj = scene.findObject("map_shade_center")
    if (!::checkObj(obj))
      return

    obj.size = ::format("%d, %d", rangeSize[0], rangeSize[1])
    obj.pos  = ::format("%d, %d", rangePos[0], rangePos[1])

    local gap = {
      t = rangePos[1]
      r = mapSize[0] - rangePos[0] - rangeSize[0]
      b = mapSize[1] - rangePos[1] - rangeSize[1]
      l = rangePos[0]
    }

    obj = scene.findObject("map_shade_t")
    obj.show(gap.t > 0)
    if (::checkObj(obj) && gap.t > 0)
    {
      obj.size = ::format("%d, %d", mapSize[0], gap.t)
      obj.pos  = ::format("%d, %d", 0, 0)
    }
    obj = scene.findObject("map_shade_b")
    obj.show(gap.b > 0)
    if (::checkObj(obj) && gap.b > 0)
    {
      obj.size = ::format("%d, %d", mapSize[0], gap.b)
      obj.pos  = ::format("%d, %d", 0, rangePos[1] + rangeSize[1])
    }
    obj = scene.findObject("map_shade_l")
    obj.show(gap.l > 0)
    if (::checkObj(obj) && gap.l > 0)
    {
      obj.size = ::format("%d, %d", gap.l, rangeSize[1])
      obj.pos  = ::format("%d, %d", 0, rangePos[1])
    }
    obj = scene.findObject("map_shade_r")
    obj.show(gap.r > 0)
    if (::checkObj(obj) && gap.r > 0)
    {
      obj.size = ::format("%d, %d", gap.r, rangeSize[1])
      obj.pos  = ::format("%d, %d", rangePos[0] + rangeSize[0], rangePos[1])
    }
  }

  function updateShotcutImages()
  {
    local placeObj = scene.findObject("shortcuts_block")
    if (!::checkObj(placeObj))
      return

    local showShortcuts = [
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
        local shortcuts = ::get_shortcuts(info.shortcuts)
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
            ::format("controlsHelpHint { text:t='#%s' }", info.title))
        else
          data.append(::handyman.renderCached("gui/commonParts/button", {
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
    ::toggle_shortcut("ID_CHANGE_ARTILLERY_TARGETING_MODE")
  }

  function getShortcutFrameForHelp(shortcut)
  {
    local data = "";
    if (!shortcut)
      return "text { text-align:t='center'; text:t='---' }"

    local curPreset = ::g_controls_manager.getCurPreset()
    for (local k = 0; k < shortcut.dev.len(); k++)
    {
      local name = ::getLocalizedControlName(curPreset, shortcut.dev[k], shortcut.btn[k]);
      local buttonFrame = format("controlsHelpBtn { text:t='%s'; font:t='%s' }", ::g_string.stripTags(name), (name.len()>2)? "@fontTiny" : "@fontMedium");

      if (shortcut.dev[k] == ::STD_MOUSE_DEVICE_ID)
      {
        local mouseBtnImg = "controlsHelpMouseBtn { background-image:t='#ui/gameuiskin#%s'; }"
        if (shortcut.btn[k] == 0)
          buttonFrame = format(mouseBtnImg, "mouse_left");
        else if (shortcut.btn[k] == 1)
          buttonFrame = format(mouseBtnImg, "mouse_right");
        else if (shortcut.btn[k] == 2)
          buttonFrame = format(mouseBtnImg, "mouse_center");
      }

      if (shortcut.dev[k] == ::JOYSTICK_DEVICE_0_ID)
      {
        local btnId = shortcut.btn[k]
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

    local { ready, enabled } = getArtilleryStatus()
    artilleryEnabledCheckCooldown = 0.3
    artilleryEnabled = enabled
    artilleryReady = ready
    if (!enabled)
      doQuitDelayed()
  }

  function getArtilleryStatus()
  {
    local { cooldown = 1 } = ::get_action_bar_items().findvalue(@(i) i.type == ::EII_ARTILLERY_TARGET)
    return {
      enabled = cooldown != 1
      ready = cooldown == 0
    }
  }

  function getMouseCursorMapCoords()
  {
    local res = ::is_xinput_device() && !isGamepadMouse ? mapCoords : null

    local cursorPos = ::get_dagui_mouse_cursor_pos()
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
    if (getArtilleryStatus().ready && mapCoords && ::artillery_dispersion(mapCoords[0], mapCoords[1]) >= 0)
    {
      ::call_artillery(mapCoords[0], mapCoords[1])
      doQuit()
    }
  }

  function goBack()
  {
    if (::is_in_flight())
      ::artillery_cancel()
    else
      doQuit()
  }

  function doQuit()
  {
    ::on_artillery_close()
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

::close_artillery_map <- @() ::broadcastEvent("CloseArtilleryRequest") // called from client

::on_artillery_targeting <- function on_artillery_targeting(params = {}) // called from client
{
  if(::is_in_flight())
    ::gui_start_artillery_map(params)
}

::artillery_call_by_shortcut <- function artillery_call_by_shortcut() // called from client
{
  local handler = ::handlersManager.getActiveBaseHandler()
  if (handler && (handler instanceof ::gui_handlers.ArtilleryMap))
    handler.onApplyByShortcut()
}
