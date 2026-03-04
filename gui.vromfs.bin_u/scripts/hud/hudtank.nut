from "%scripts/dagui_library.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { getUAVCameraEnabled, getShowUAVCameraToggle } = require("hudTankStates")
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { initIconedHints } = require("%scripts/hud/iconedHints.nut")
let { ActionBar } = require("%scripts/hud/hudActionBar.nut")
let { hudDisplayTimersInit, hudDisplayTimersReInit } = require("%scripts/hud/hudDisplayTimers.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let hudEnemyDamage = require("%scripts/hud/hudEnemyDamage.nut")
let { isInKillerCamera } = require("%scripts/hud/hudState.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")

function updateTacticalMapSwitchingObj(obj, value) {
  obj.findObject("map_btn").toggled = value ? "no" : "yes"
  obj.findObject("uav_btn").toggled = value ? "yes" : "no"
}

let switchTacticalMapView = @() toggleShortcut("ID_TOGGLE_UAV_CAMERA")

function getShortcutIdForSwitchTacticalMap() {
  let isBound = g_shortcut_type.getShortcutTypeByShortcutId("ID_TOGGLE_UAV_CAMERA").isAssigned("ID_TOGGLE_UAV_CAMERA")
  if (isBound)
    return "ID_TOGGLE_UAV_CAMERA"

  return "ID_SHOW_MULTIFUNC_WHEEL_MENU"
}

let HudTank = class (gui_handlers.BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudTank.blk"

  needForceUpdateTacticalMapHint = false

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_TANK)
    initIconedHints(this.scene, ES_UNIT_TYPE_TANK)
    hudEnemyDamage.init(this.scene)
    let actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()
    this.updateShowHintsNest()
    this.updatePosHudMultiplayerScore()
    this.updateTacticalMapVisibility()
    this.updateTacticalMapSwitching()
  }

  function reinitScreen(_params = {}) {
    this.actionBarWeak?.reinit()
    hudEnemyDamage.reinit()
    hudDisplayTimersReInit()
    this.updateShowHintsNest()
    this.updateTacticalMapVisibility()
    this.updateTacticalMapSwitching()
  }

  function updateShowHintsNest() {
    showObjById("actionbar_hints_nest", true, this.scene)
  }

  function updateTacticalMapVisibility() {
    let isTacticalMapVisible = !isInKillerCamera.get()
      && !isAAComplexMenuActive.get()
      && g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)

    showObjById("hud_tank_tactical_map_nest", isTacticalMapVisible, this.scene)
  }

  function updateTacticalMapSwitching() {
    let objMap = this.scene.findObject("tactical_map_switching")
    if (!objMap?.isValid())
      return

    let hintObj = objMap.findObject("shortcut_hint")
    if (this.needForceUpdateTacticalMapHint) {
      hintObj.setValue("")
      this.needForceUpdateTacticalMapHint = false
    }
    hintObj.setValue("".concat("{{", getShortcutIdForSwitchTacticalMap(), "}}"))
    objMap.setValue(stashBhvValueConfig([
      {
        watch = getShowUAVCameraToggle()
        updateFunc = @(obj, value) obj.show(value)
      },
      {
        watch = getUAVCameraEnabled()
        updateFunc = updateTacticalMapSwitchingObj
      }
    ]))
  }

  function onControlsChanged() {
    base.onControlsChanged()
    this.needForceUpdateTacticalMapHint = true
  }

  function onSwitchToTacticalMap(_) {
    if (!getUAVCameraEnabled().get())
      return
    switchTacticalMapView()
  }

  function onSwitchToUAVCamera(_) {
    if (getUAVCameraEnabled().get())
      return
    switchTacticalMapView()
  }
}

return {
  HudTank
}