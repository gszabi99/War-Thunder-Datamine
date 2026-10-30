import "%scripts/options/optionsMeasureUnits.nut" as optionsMeasureUnits
import "DataBlock" as DataBlock
from "%scripts/options/optionsStorage.nut" import set_crosshair_icons, set_thermovision_colors, set_modifications_locId_by_caliber, set_bullets_locId_by_caliber, set_available_ship_hit_notifications
from "%scripts/postFxSettings.nut" import init_postfx
from "%scripts/viewUtils/layeredIcon.nut" import LayersIcon
from "%scripts/weaponry/bulletsVisual.nut" import initBulletIcons
from "%scripts/weaponry/weaponsParams.nut" import initWeaponParams
from "%scripts/missions/missionsUtils.nut" import clearMapsCache
from "%scripts/ranks.nut" import updateAircraftWarpoints, loadPlayerExpTable, initPrestigeByRank, calculateMaxRank
from "%scripts/langUtils/localization.nut" import setUnlocksPunctuationWithoutSpace
from "%scripts/unit/initUnits.nut" import initAllUnits, updateAllUnits
from "%scripts/options/initOptionsState.nut" import hasOptionsInitialized
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *
from "types" import String

let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { crosshair_colors } = require("%scripts/options/optionsExt.nut")
let { tribunal } = require("%scripts/penitentiary/tribunal.nut")

let initOptionsSteps = [
  initAllUnits
  updateAllUnits
  calculateMaxRank
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

    if (blk?.unlocks_punctuation_without_space instanceof String)
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
  if (hasOptionsInitialized())
    return

  local stepStatus
  foreach (action in initOptionsSteps)
    do {
      stepStatus = action()
    } while (stepStatus == PT_STEP_STATUS.SUSPEND)
}

return {
  initOptions
  initOptionsSteps
}
