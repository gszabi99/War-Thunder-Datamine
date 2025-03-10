from "%scripts/dagui_natives.nut" import get_global_stats_blk, disable_network, gather_and_build_aircrafts_list
from "%scripts/dagui_library.nut" import *

let { set_crosshair_icons, set_thermovision_colors, set_modifications_locId_by_caliber, set_bullets_locId_by_caliber,
  set_available_ship_hit_notifications } = require("%scripts/options/optionsStorage.nut")
let { init_postfx } = require("%scripts/postFxSettings.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let Unit = require("%scripts/unit/unit.nut")
let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")
let { initBulletIcons } = require("%scripts/weaponry/bulletsVisual.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { initWeaponParams } = require("%scripts/weaponry/weaponsParams.nut")
let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { generateUnitShopInfo } = require("%scripts/shop/shopUnitsInfo.nut")
let { floor } = require("math")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_shop_blk } = require("blkGetters")
let { clearMapsCache } = require("%scripts/missions/missionsUtils.nut")
let { updateAircraftWarpoints, loadPlayerExpTable, initPrestigeByRank } = require("%scripts/ranks.nut")
let { setUnlocksPunctuationWithoutSpace } = require("%scripts/langUtils/localization.nut")
let { crosshair_colors } = require("%scripts/options/optionsExt.nut")
let { isAuthorized } = require("%appGlobals/login/loginState.nut")

let allUnits = getAllUnits()

foreach (name, unit in allUnits)
  allUnits[name] = Unit({}).setFromUnit(unit)
if (showedUnit.value != null)
  showedUnit(allUnits?[showedUnit.value.name])

::init_options <- function init_options() {
  if (optionsMeasureUnits.isInitialized() && (isAuthorized.get() || disable_network()))
    return

  local stepStatus
  foreach (action in ::init_options_steps)
    do {
      stepStatus = action()
    } while (stepStatus == PT_STEP_STATUS.SUSPEND)
}

function init_all_units() { 
  allUnits.clear()
  let all_units_array = gather_and_build_aircrafts_list()
  foreach (unitTbl in all_units_array) {
    local unit = Unit(unitTbl)
    allUnits[unit.name] <- unit
  }
}

local usageAmountCounted = false
function countUsageAmountOnce() {
  if (usageAmountCounted)
    return

  let statsblk = get_global_stats_blk()
  if (!statsblk?.aircrafts)
    return

  let shopStatsAirs = []
  let shopBlk = get_shop_blk()

  for (local tree = 0; tree < shopBlk.blockCount(); tree++) {
    let tblk = shopBlk.getBlock(tree)
    for (local page = 0; page < tblk.blockCount(); page++) {
      let pblk = tblk.getBlock(page)
      for (local range = 0; range < pblk.blockCount(); range++) {
        let rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++) {
          let airBlk = rblk.getBlock(a)
          let stats = statsblk.aircrafts?[airBlk.getBlockName()]
          if (stats?.flyouts_factor)
            shopStatsAirs.append(stats.flyouts_factor)
        }
      }
    }
  }

  if (shopStatsAirs.len() <= ::usageRating_amount.len())
    return

  shopStatsAirs.sort(function(a, b) {
    if (a > b)
      return 1
    else if (a < b)
      return -1
    return 0;
  })

  for (local i = 0; i < ::usageRating_amount.len(); i++) {
    let idx = floor((i + 1).tofloat() * shopStatsAirs.len() / (::usageRating_amount.len() + 1) + 0.5)
    ::usageRating_amount[i] = (idx == shopStatsAirs.len() - 1) ? shopStatsAirs[idx] : 0.5 * (shopStatsAirs[idx] + shopStatsAirs[idx + 1])
  }
  usageAmountCounted = true
}

::update_all_units <- function update_all_units() {
  updateShopCountriesList()
  countUsageAmountOnce()
  generateUnitShopInfo()

  log("update_all_units called, got", allUnits.len(), "items");
}

::init_options_steps <- [
  init_all_units
  ::update_all_units
  function() { return updateAircraftWarpoints(10) }

  function() {
    ::tribunal.init()
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
