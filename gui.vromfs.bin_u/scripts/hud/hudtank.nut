from "%scripts/hud/baseUnitHud.nut" import BaseUnitHud
from "%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut" import stashBhvValueConfig
from "%scripts/hud/iconedHints.nut" import initIconedHints
from "%scripts/hud/hudActionBar.nut" import ActionBar
from "%scripts/hud/hudDisplayTimers.nut" import hudDisplayTimersInit, hudDisplayTimersReInit
from "%scripts/hud/hudState.nut" import isInKillerCamera
from "%globalScripts/controls/shortcutActions.nut" import toggleShortcut
from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive
from "hudTankStates" import uavCameraEnabled, canEnableUavCamera
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/hud/hudConsts.nut" import HUD_VIS_PART

let { g_hud_vis_mode } = require("%scripts/hud/hudVisMode.nut")
let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let hudEnemyDamage = require("%scripts/hud/hudEnemyDamage.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

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

let HudTank = class (BaseUnitHud) {
  sceneBlkName = "%gui/hud/hudTank.blk"
  killFeedPlace = { height = "0.2@shHud", gap = "0.01@shHud", aboveId = "hud_tank_tactical_map_nest" }
  hasMpScore = true

  needForceUpdateTacticalMapHint = false

  function initScreen() {
    base.initScreen()
    hudDisplayTimersInit(this.scene, ES_UNIT_TYPE_TANK)
    initIconedHints(this.scene, ES_UNIT_TYPE_TANK)
    hudEnemyDamage.init(this.scene)
    let actionBar = ActionBar(this.scene.findObject("hud_action_bar"))
    this.actionBarWeak = actionBar.weakref()
    this.updateTacticalMapVisibility()
    this.updateTacticalMapSwitching()
  }

  function reinitScreen(_params = {}) {
    this.actionBarWeak?.reinit()
    hudEnemyDamage.reinit()
    hudDisplayTimersReInit()
    this.updateTacticalMapVisibility()
    this.updateTacticalMapSwitching()
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
        watch = canEnableUavCamera
        function updateFunc(obj, value) {
          obj.show(value)
          obj.getScene().applyPendingChanges(false)
          handlersManager.updateWidgets()
        }
      },
      {
        watch = uavCameraEnabled
        updateFunc = updateTacticalMapSwitchingObj
      }
    ]))
  }

  function onControlsChanged() {
    base.onControlsChanged()
    this.needForceUpdateTacticalMapHint = true
  }

  function onSwitchToTacticalMap(_) {
    if (!uavCameraEnabled.get())
      return
    switchTacticalMapView()
  }

  function onSwitchToUAVCamera(_) {
    if (uavCameraEnabled.get())
      return
    switchTacticalMapView()
  }
}

return freeze({
  HudTank
})
