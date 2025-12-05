from "%scripts/dagui_library.nut" import *

let { set_crosshair_icons, set_thermovision_colors, set_modifications_locId_by_caliber, set_bullets_locId_by_caliber,
  set_available_ship_hit_notifications } = require("%scripts/options/optionsStorage.nut")
let { init_postfx } = require("%scripts/postFxSettings.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")
let { initBulletIcons } = require("%scripts/weaponry/bulletsVisual.nut")
let { initWeaponParams } = require("%scripts/weaponry/weaponsParams.nut")
let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { clearMapsCache } = require("%scripts/missions/missionsUtils.nut")
let { updateAircraftWarpoints, loadPlayerExpTable, initPrestigeByRank } = require("%scripts/ranks.nut")
let { setUnlocksPunctuationWithoutSpace } = require("%scripts/langUtils/localization.nut")
let { crosshair_colors } = require("%scripts/options/optionsExt.nut")
let { isAuthorized } = require("%appGlobals/login/loginState.nut")
let { tribunal } = require("%scripts/penitentiary/tribunal.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")
let { initAllUnits, updateAllUnits } = require("%scripts/unit/initUnits.nut")

let initOptionsSteps = [
  initAllUnits
  updateAllUnits
  function() { return updateAircraftWarpoints(10) }

  function() {
    tribunal.init()
    clearMapsCache() 
    set_crosshair_icons([])
    crosshair_colors.clear()
    set_thermovision_colors([])
  }

  @() optionsMeasureUnits.init()

  function() {
    let blk = GUI.get()

    initBulletIcons(blk)

    set_bullets_locId_by_caliber(blk?["bullets_locId_by_caliber"] ? (blk["bullets_locId_by_caliber"] % "ending") : [])
    set_modifications_locId_by_caliber(blk?["modifications_locId_by_caliber"] ? (blk["modifications_locId_by_caliber"] % "ending") : [])

    if (type(blk?.unlocks_punctuation_without_space) == "string")
      setUnlocksPunctuationWithoutSpace(blk.unlocks_punctuation_without_space)

    LayersIcon.initConfigOnce(blk)
  }

  function() {
    let blk = DataBlock()
    blk.load("config/hud.blk")
    if (blk?.crosshair) {
      let crosshairs = blk.crosshair % "pictureTpsView"
      let new_crosshairs = []
      foreach (crosshair in crosshairs)
        new_crosshairs.append(crosshair)
      set_crosshair_icons(new_crosshairs)
      let colors = blk.crosshair % "crosshairColor"
      foreach (colorBlk in colors)
        crosshair_colors.append({
          name = colorBlk.name
          color = colorBlk.color
        })
    }
    if (blk?.thermovision) {
      let clrs = blk.thermovision % "color"
      let new_thermovision_colors = []
      foreach (colorBlk in clrs) {
        new_thermovision_colors.append({ menu_rgb = colorBlk.menu_rgb })
      }
      set_thermovision_colors(new_thermovision_colors)
    }
    if (blk?.shipHitNotification) {
      let { shipHitNotification } = blk
      let availableHitNotifications = {}
      for (local i = 0; i < shipHitNotification.blockCount(); i++) {
        let hitNotificationBlk = shipHitNotification.getBlock(i)
        if (hitNotificationBlk?.enabled)
          availableHitNotifications[hitNotificationBlk.getBlockName()] <- true
      }
      set_available_ship_hit_notifications(availableHitNotifications)
    }
  }

  function() {
    initWeaponParams()
  }

  function() {
    loadPlayerExpTable()
    initPrestigeByRank()
  }

  init_postfx

  function() {
    broadcastEvent("InitConfigs")
  }
]

function initOptions() {
  if (optionsMeasureUnits.isInitialized() && (isAuthorized.get() || disableNetwork))
    return

  local stepStatus
  foreach (action in initOptionsSteps)
    do {
      stepStatus = action()
    } while (stepStatus == PT_STEP_STATUS.SUSPEND)
}

::init_options_steps <- initOptionsSteps

return {
  initOptions
}
