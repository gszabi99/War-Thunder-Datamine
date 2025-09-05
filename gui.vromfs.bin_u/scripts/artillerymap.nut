from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isXInputDevice } = require("controls")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { round } = require("math")
let { format } = require("string")
let { getArtilleryDispersion, callArtillery, onArtilleryClose, artilleryCancel,
  getMapRelativePlayerPos, getArtilleryRange } = require("guiArtillery")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let { getArtilleryAxisWatch, getAxisStuck, getAxisData,
  getMaxDeviatedAxisInfo, getPositionDelta}  = require("%scripts/joystickInterface.nut")
let { setMousePointerInitialPos } = require("%scripts/controls/mousePointerInitialPos.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { getActionBarItems } = require("hudActionBar")
let { getActionItemStatus } = require("%scripts/hud/hudActionBarInfo.nut")
let { EII_ARTILLERY_TARGET } = require("hudActionBarConst")
let { stripTags } = require("%sqstd/string.nut")
let { get_mission_difficulty_int } = require("guiMission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { isInFlight } = require("gameplayBinding")
let { getLocalizedControlName } = require("%scripts/controls/controlsVisual.nut")
let { getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

enum POINTING_DEVICE {
  MOUSE
  TOUCHSCREEN
  JOYSTICK
  GAMEPAD
}

gui_handlers.ArtilleryMap <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/artilleryMap.blk"
  shouldBlurSceneBg = true
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

  function initScreen() {
    let objMap = this.scene.findObject("tactical_map")
    if (checkObj(objMap)) {
      this.mapPos  = objMap.getPos()
      this.mapSize = objMap.getSize()
    }

    this.objTarget = this.scene.findObject(this.isSuperArtillery ? "super_artillery_target" : "artillery_target")
    if (checkObj(this.objTarget)) {
      if (this.isSuperArtillery) {
        this.objTarget["background-image"] = this.iconSuperArtilleryZone
        let objTargetCenter = this.scene.findObject("super_artillery_target_center")
        objTargetCenter["background-image"] = this.iconSuperArtilleryTarget
      }
    }

    this.watchAxis = getArtilleryAxisWatch()
    this.isGamepadMouse = ::g_gamepad_cursor_controls.getValue()
    this.pointingDevice = useTouchscreen ? POINTING_DEVICE.TOUCHSCREEN
      : isXInputDevice() && !this.isGamepadMouse ? POINTING_DEVICE.GAMEPAD
      : POINTING_DEVICE.MOUSE

    this.canUseShortcuts = !useTouchscreen || isXInputDevice()
    this.shouldMapClickDoApply = !useTouchscreen && !isXInputDevice()

    g_hud_event_manager.subscribe("LocalPlayerDead", @(_data) this.doQuitDelayed(), this)

    this.reinitScreen()
  }

  function reinitScreen(params = {}) {
    this.setParams(params)

    let isStick = this.pointingDevice == POINTING_DEVICE.GAMEPAD || this.pointingDevice == POINTING_DEVICE.JOYSTICK
    this.prevMousePos = isStick ? get_dagui_mouse_cursor_pos() : [-1, -1]
    this.mapCoords = isStick ? [0.5, 0.5] : null
    this.stuckAxis = getAxisStuck(this.watchAxis)

    this.scene.findObject("update_timer").setUserData(this)
    this.update(null, 0.0)
    this.updateShotcutImages()

    setMousePointerInitialPos(this.scene.findObject("tactical_map"))
  }

  function update(_obj = null, dt = 0.0) {
    if (!checkObj(this.objTarget))
      return

    let prevArtilleryReady = this.artilleryReady
    this.checkArtilleryEnabledByTimer(dt)

    local curPointingice = this.pointingDevice
    let mousePos = get_dagui_mouse_cursor_pos()
    let axisData = getAxisData(this.watchAxis, this.stuckAxis)
    let joystickData = getMaxDeviatedAxisInfo(axisData)

    if (mousePos[0] != this.prevMousePos[0] || mousePos[1] != this.prevMousePos[1]) {
      curPointingice = useTouchscreen ? POINTING_DEVICE.TOUCHSCREEN : POINTING_DEVICE.MOUSE
      this.mapCoords = this.getMouseCursorMapCoords()
    }
    else if (!this.isGamepadMouse && (joystickData.x || joystickData.y)) {
      curPointingice = isXInputDevice() ? POINTING_DEVICE.GAMEPAD : POINTING_DEVICE.JOYSTICK
      let displasement = getPositionDelta(dt, 3, joystickData)
      let prevMapCoords = this.mapCoords ?? [0.5, 0.5]
      this.mapCoords = [
        clamp(prevMapCoords[0] + displasement[0], 0.0, 1.0),
        clamp(prevMapCoords[1] + displasement[1], 0.0, 1.0)
      ]
    }

    this.prevMousePos = mousePos
    if (curPointingice != this.pointingDevice || prevArtilleryReady != this.artilleryReady)
      this.pointingDevice = curPointingice

    let show = this.mapCoords != null
    let disp = this.mapCoords ? getArtilleryDispersion(this.mapCoords[0], this.mapCoords[1]) : -1
    local valid = show && disp >= 0 && this.artilleryEnabled
    let dispersionRadius = valid ? (this.isSuperArtillery ? this.superStrikeRadius / this.mapSizeMeters : disp) : this.invalidTargetDispersionRadius
    valid = valid && this.artilleryReady

    this.objTarget.show(show)
    if (show) {
      let sizePx = round(this.mapSize[0] * dispersionRadius) * 2
      let posX = 1.0 * this.mapSize[0] * this.mapCoords[0]
      let posY = 1.0 * this.mapSize[1] * this.mapCoords[1]
      this.objTarget.size = format("%d, %d", sizePx, sizePx)
      this.objTarget.pos = format("%d-w/2, %d-h/2", posX, posY)
      if (!this.isSuperArtillery)
        this.objTarget.enable(valid)
    }

    let objHint = this.scene.findObject("txt_artillery_hint")
    if (checkObj(objHint)) {
      objHint.setValue(loc(valid ? "artillery_strike/allowed" :
        (this.artilleryEnabled ?
          (this.artilleryReady ? "artillery_strike/not_allowed" : "artillery_strike/not_ready") :
          "artillery_strike/crew_lost")))
      objHint.overlayTextColor = valid ? "good" : "bad"
    }

    let objBtnApply = this.scene.findObject("btn_apply")
    if (checkObj(objBtnApply))
      objBtnApply.enable(valid)

    this.updateMapShadeRadius()
  }

  function updateMapShadeRadius() {
    local avatarPos = getMapRelativePlayerPos()
    avatarPos = avatarPos.len() == 2 ? avatarPos : [ 0.5, 0.5 ]
    let diameter  = this.isSuperArtillery ? 3.0 : (isInFlight() ? getArtilleryRange() * 2 : 1.0)
    let rangeSize = [ round(this.mapSize[0] * diameter), round(this.mapSize[1] * diameter) ]
    let rangePos  = [ round(this.mapSize[0] * avatarPos[0] - rangeSize[0] / 2), round(this.mapSize[1] * avatarPos[1] - rangeSize[1] / 2) ]

    if (rangePos[0] == this.prevShadeRangePos[0] && rangePos[1] == this.prevShadeRangePos[1])
      return
    this.prevShadeRangePos = rangePos

    this.invalidTargetDispersionRadius = this.invalidTargetDispersionRadiusMeters.tofloat() / this.mapSizeMeters * diameter

    local obj = this.scene.findObject("map_shade_center")
    if (!checkObj(obj))
      return

    obj.size = format("%d, %d", rangeSize[0], rangeSize[1])
    obj.pos  = format("%d, %d", rangePos[0], rangePos[1])

    let gap = {
      t = rangePos[1]
      r = this.mapSize[0] - rangePos[0] - rangeSize[0]
      b = this.mapSize[1] - rangePos[1] - rangeSize[1]
      l = rangePos[0]
    }

    obj = this.scene.findObject("map_shade_t")
    obj.show(gap.t > 0)
    if (checkObj(obj) && gap.t > 0) {
      obj.size = format("%d, %d", this.mapSize[0], gap.t)
      obj.pos  = format("%d, %d", 0, 0)
    }
    obj = this.scene.findObject("map_shade_b")
    obj.show(gap.b > 0)
    if (checkObj(obj) && gap.b > 0) {
      obj.size = format("%d, %d", this.mapSize[0], gap.b)
      obj.pos  = format("%d, %d", 0, rangePos[1] + rangeSize[1])
    }
    obj = this.scene.findObject("map_shade_l")
    obj.show(gap.l > 0)
    if (checkObj(obj) && gap.l > 0) {
      obj.size = format("%d, %d", gap.l, rangeSize[1])
      obj.pos  = format("%d, %d", 0, rangePos[1])
    }
    obj = this.scene.findObject("map_shade_r")
    obj.show(gap.r > 0)
    if (checkObj(obj) && gap.r > 0) {
      obj.size = format("%d, %d", gap.r, rangeSize[1])
      obj.pos  = format("%d, %d", rangePos[0] + rangeSize[0], rangePos[1])
    }
  }

  function updateShotcutImages() {
    let placeObj = this.scene.findObject("shortcuts_block")
    if (!checkObj(placeObj))
      return

    let showShortcuts = [
      {
        title = "hotkeys/ID_SHOOT_ARTILLERY"
        shortcuts = ["ID_SHOOT_ARTILLERY"]
        buttonCb = "onApply"
        buttonExtraMarkup = is_dev_version() ? "accessKey:t='Enter';" : ""
        buttonId = "btn_apply"
      },
      {
        title = "hotkeys/ID_CHANGE_ARTILLERY_TARGETING_MODE"
        shortcuts = ["ID_CHANGE_ARTILLERY_TARGETING_MODE"]
        buttonCb = "onChangeTargetingMode"
        show = get_mission_difficulty_int() != DIFFICULTY_HARDCORE && !this.isSuperArtillery
      },
      {
        title = "mainmenu/btnCancel"
        shortcuts = ["ID_ARTILLERY_CANCEL", "ID_ACTION_BAR_ITEM_5"]
        buttonCb = "goBack"
      },
    ]

    local reqDevice = STD_MOUSE_DEVICE_ID
    if (showConsoleButtons.get() || this.pointingDevice == POINTING_DEVICE.GAMEPAD || this.pointingDevice == POINTING_DEVICE.JOYSTICK)
      reqDevice = JOYSTICK_DEVICE_0_ID
    else if (this.pointingDevice == POINTING_DEVICE.TOUCHSCREEN)
      reqDevice = STD_KEYBOARD_DEVICE_ID

    foreach (_idx, info in showShortcuts)
      if (info?.show ?? true) {
        let shortcuts = getShortcuts(info.shortcuts)
        local pref = null
        local any = null
        foreach (i, actionShortcuts in shortcuts) {
          info.primaryShortcutName <- info.shortcuts[i]
          foreach (shortcut in actionShortcuts) {
            any = any || shortcut
            if (find_in_array(shortcut.dev, reqDevice) >= 0) {
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
    foreach (_idx, info in showShortcuts)
      if (info?.show ?? true) {
        if (this.canUseShortcuts)
          data.append("".concat(this.getShortcutFrameForHelp(info.primaryShortcut),
            format("controlsHelpHint { text:t='#%s' }", info.title)))
        else
          data.append(handyman.renderCached("%gui/commonParts/button.tpl", {
            id = info?.buttonId ?? ""
            text =$"#{info.title}"
            funcName = info.buttonCb
            actionParamsMarkup = info?.buttonExtraMarkup
          }))
      }

    data = "controlsHelpHint { text:t='    ' }".join(data, true)
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function onChangeTargetingMode(_obj) {
    toggleShortcut("ID_CHANGE_ARTILLERY_TARGETING_MODE")
  }

  function getShortcutFrameForHelp(shortcut) {
    local data = "";
    if (!shortcut)
      return "text { text-align:t='center'; text:t='---' }"

    let curPreset = getCurControlsPreset()
    for (local k = 0; k < shortcut.dev.len(); k++) {
      let name = getLocalizedControlName(curPreset, shortcut.dev[k], shortcut.btn[k]);
      local buttonFrame = format("controlsHelpBtn { text:t='%s'; font:t='%s' }", stripTags(name), (name.len() > 2) ? "@fontTiny" : "@fontMedium");

      if (shortcut.dev[k] == STD_MOUSE_DEVICE_ID) {
        let mouseBtnImg = "controlsHelpMouseBtn { background-image:t='#ui/gameuiskin#%s'; }"
        if (shortcut.btn[k] == 0)
          buttonFrame = format(mouseBtnImg, "mouse_left");
        else if (shortcut.btn[k] == 1)
          buttonFrame = format(mouseBtnImg, "mouse_right");
        else if (shortcut.btn[k] == 2)
          buttonFrame = format(mouseBtnImg, "mouse_center");
      }

      if (shortcut.dev[k] == JOYSTICK_DEVICE_0_ID) {
        let btnId = shortcut.btn[k]
        if (gamepadIcons.hasTextureByButtonIdx(btnId))
          buttonFrame = format("controlsHelpJoystickBtn { background-image:t='%s' }",
            gamepadIcons.getTextureByButtonIdx(btnId))
      }

      data = "".concat(data,
        ((k != 0) ? "text { pos:t='0,0.5ph-0.5h';position:t='relative';text-align:t='center';text:t='+'}" : ""),
        buttonFrame)
    }

    return data;
  }

  function checkArtilleryEnabledByTimer(dt = 0.0) {
    this.artilleryEnabledCheckCooldown -= dt
    if (this.artilleryEnabledCheckCooldown > 0)
      return

    let { isReady, isAvailable } = this.getArtilleryStatus()
    this.artilleryEnabledCheckCooldown = 0.3
    this.artilleryEnabled = isAvailable
    this.artilleryReady = isReady
    if (!isAvailable)
      this.doQuitDelayed()
  }

  getArtilleryStatus = @() getActionItemStatus(getActionBarItems().findvalue(@(i) i.type == EII_ARTILLERY_TARGET))

  function getMouseCursorMapCoords() {
    local res = isXInputDevice() && !this.isGamepadMouse ? this.mapCoords : null

    let cursorPos = get_dagui_mouse_cursor_pos()
    if (cursorPos[0] >= this.mapPos[0] && cursorPos[0] <= this.mapPos[0] + this.mapSize[0] && cursorPos[1] >= this.mapPos[1] && cursorPos[1] <= this.mapPos[1] + this.mapSize[1])
      res = [
        1.0 * (cursorPos[0] - this.mapPos[0]) / this.mapSize[0],
        1.0 * (cursorPos[1] - this.mapPos[1]) / this.mapSize[1],
      ]

    return res
  }

  function onArtilleryMapClick() {
    this.mapCoords = this.getMouseCursorMapCoords()
    
    
    if (this.shouldMapClickDoApply)
      this.onApply()
  }

  function onOutsideMapClick() {
    if (this.shouldMapClickDoApply)
      this.goBack()
  }

  function onApplyByShortcut() {
    
    if (!this.canUseShortcuts)
      return
    this.onApply()
  }

  function onApply() {
    if (this.getArtilleryStatus().isReady && this.mapCoords && getArtilleryDispersion(this.mapCoords[0], this.mapCoords[1]) >= 0) {
      callArtillery(this.mapCoords[0], this.mapCoords[1])
      this.doQuit()
    }
  }

  function goBack() {
    if (isInFlight())
      artilleryCancel()
    else
      this.doQuit()
  }

  function doQuit() {
    onArtilleryClose()
    if (this.isSceneActive())
      base.goBack()
  }

  doQuitDelayed = @() this.guiScene.performDelayed(this, function() {
    if (this.isValid())
      this.doQuit()
  })
  onEventCloseArtilleryRequest = @(_p) this.doQuitDelayed()

  function onEventHudTypeSwitched(_params) {
    this.doQuitDelayed()
  }
}

function guiStartArtilleryMap(params = {}) {
  handlersManager.loadHandler(gui_handlers.ArtilleryMap,
  {
    mapSizeMeters = params?.mapSizeMeters ?? 1400
    isSuperArtillery = getTblValue("useCustomSuperArtillery", params, false)
    superStrikeRadius = getTblValue("artilleryStrikeRadius", params, 0.0),
    iconSuperArtilleryZone = "".concat("#ui/gameuiskin#", getTblValue("iconSuperArtilleryZoneName", params, "")),
    iconSuperArtilleryTarget = "".concat("#ui/gameuiskin#", getTblValue("iconSuperArtilleryTargetName", params, ""))
  })
}

eventbus_subscribe("artilleryMapOpen", @(p) isInFlight() ? guiStartArtilleryMap(p) : null)
eventbus_subscribe("artilleryMapClose", @(_) broadcastEvent("CloseArtilleryRequest"))
eventbus_subscribe("artilleryCallByShortcut", function(_) {
  let handler = handlersManager.getActiveBaseHandler()
  if (handler && (handler instanceof gui_handlers.ArtilleryMap))
    handler.onApplyByShortcut()
})
