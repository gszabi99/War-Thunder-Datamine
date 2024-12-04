// warning disable: -file:forbidden-function
from "%scripts/dagui_natives.nut" import rented_units_get_expired_time_sec, get_user_logs_count, get_user_log_blk_body, shop_is_unit_rented, rented_units_get_last_max_full_rent_time, char_send_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import INFO_DETAIL

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let userstat = require("userstat")
//let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format, split_by_chars } = require("string")
let DataBlock  = require("DataBlock")
let { blkFromPath } = require("%sqstd/datablock.nut")
let dbgExportToFile = require("%globalScripts/debugTools/dbgExportToFile.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { getWeaponInfoText, getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { isWeaponAux, getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { userstatStats, userstatDescList, userstatUnlocks, refreshUserstatStats
} = require("%scripts/userstat/userstat.nut")
let { getDebriefingResult, setDebriefingResult } = require("%scripts/debriefing/debriefingFull.nut")
let { guiStartDebriefingFull } = require("%scripts/debriefing/debriefingModal.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { getUnitMassPerSecValue } = require("%scripts/unit/unitWeaponryInfo.nut")
let { register_command } = require("console")
let { get_meta_mission_info_by_gm_and_name } = require("guiMission")
let { hotasControlImagePath } = require("%scripts/controls/hotas.nut")
let { startsWith, stripTags } = require("%sqstd/string.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { get_wpcost_blk } = require("blkGetters")
require("%scripts/debugTools/dbgLongestUnitTooltip.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { reload_dagui } = require("%scripts/debugTools/dbgUtils.nut")
let { gui_start_decals } = require("%scripts/customization/contentPreview.nut")
let { guiStartImageWnd } = require("%scripts/showImage.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")

function _charAddAllItemsHelper(params) {
  if (params.currentIndex >= params.items.len())
    return
  let item = params.items[params.currentIndex]
  let blk = DataBlock()
  blk.setStr("what", "addItem")
  blk.setStr("item", item.id)
  blk.addInt("howmuch", params.count);
  let taskId = char_send_blk("dev_hack", blk)
  if (taskId == -1)
    return

  let __charAddAllItemsHelper = _charAddAllItemsHelper // for lambda capture

  addBgTaskCb(taskId, function () {
    ++params.currentIndex
    if ((params.currentIndex == params.items.len() ||
         params.currentIndex % 10 == 0) &&
         params.currentIndex != 0)
      dlog(format("Adding items: %d/%d", params.currentIndex, params.items.len()))
    __charAddAllItemsHelper(params)
  })
}


function charAddAllItems(count = 1) {
  let params = {
    items = ::ItemsManager.getItemsList()
    currentIndex = 0
    count
  }
  _charAddAllItemsHelper(params)
}

//must to be switched on before we get to debrifing.
//but after it you can restart derifing with full recalc by usual reload()
local _stat_get_exp = null
local _stat_get_exp_cache = null

function switch_on_debug_debriefing_recount() {
  if (!_stat_get_exp)
    return

  _stat_get_exp = ::stat_get_exp
  _stat_get_exp_cache = null
  ::stat_get_exp = function() {
    _stat_get_exp_cache = _stat_get_exp() ?? _stat_get_exp_cache
    return _stat_get_exp_cache
  }
}

function debug_reload_and_restart_debriefing() {
  let result = getDebriefingResult()
  reload_dagui()

  let canRecount = _stat_get_exp != null
  if (!canRecount)
    setDebriefingResult(result)

  guiStartDebriefingFull()
}

function debug_debriefing_unlocks(unlocksAmount = 5) {
  guiStartDebriefingFull({ debugUnlocks = unlocksAmount })
}

function show_hotas_window_image() {
  guiStartImageWnd(hotasControlImagePath, 1.41)
}

function debug_export_unit_weapons_descriptions() {
  dbgExportToFile.export({
    resultFilePath = "export/unitsWeaponry.blk"
    itemsPerFrame = 10
    list = function() {
      let res = []
      let wpCost = get_wpcost_blk()
      for (local i = 0; i < wpCost.blockCount(); i++) {
        let unit = getAircraftByName(wpCost.getBlock(i).getBlockName())
        if (unit?.isInShop)
          res.append(unit)
      }
      return res
    }()
    itemProcessFunc = function(unit) {
      let blk = DataBlock()
      foreach (weapon in unit.getWeapons())
        if (!isWeaponAux(weapon)) {
          blk[$"{weapon.name}_short"] <- getWeaponNameText(unit, false, weapon.name, ", ")
          local rowsList = split_by_chars(getWeaponInfoText(unit,
            { isPrimary = false, weaponPreset = weapon.name }), "\n")
          foreach (row in rowsList)
            blk[weapon.name] <- row
          rowsList = split_by_chars(getWeaponInfoText(unit,
            { isPrimary = false, weaponPreset = weapon.name, detail = INFO_DETAIL.EXTENDED }), "\n")
          foreach (row in rowsList)
            blk[$"{weapon.name}_extended"] <- row
          rowsList = split_by_chars(getWeaponInfoText(unit,
            { weaponPreset = weapon.name, detail = INFO_DETAIL.FULL }), "\n")
          foreach (row in rowsList)
            blk[$"{weapon.name}_full"] <- row
          blk[$"{weapon.name}_massPerSec"] <- getUnitMassPerSecValue(unit, true, weapon.name)
          blk[$"{weapon.name}_bombsNbr"] <- weapon.bombsNbr
        }
      return { key = unit.name, value = blk }
    }
  })
}

function debug_export_unit_xray_parts_descriptions(partIdWhitelist = null) {
  ::dmViewer.isDebugBatchExportProcess = true
  ::dmViewer.toggle(DM_VIEWER_XRAY)
  dbgExportToFile.export({
    resultFilePath = "export/unitsXray.blk"
    itemsPerFrame = 10
    list = function() {
      let res = []
      let wpCost = get_wpcost_blk()
      for (local i = 0; i < wpCost.blockCount(); i++) {
        let unit = getAircraftByName(wpCost.getBlock(i).getBlockName())
        if (unit?.isInShop)
          res.append(unit)
      }
      return res
    }()
    itemProcessFunc = function(unit) {
      let blk = DataBlock()

      ::dmViewer.updateUnitInfo(unit.name)
      let partNames = []
      let damagePartsBlk = ::dmViewer.unitBlk?.DamageParts
      if (damagePartsBlk)
        for (local b = 0; b < damagePartsBlk.blockCount(); b++) {
          let partsBlk = damagePartsBlk.getBlock(b)
          for (local p = 0; p < partsBlk.blockCount(); p++)
            u.appendOnce(partsBlk.getBlock(p).getBlockName(), partNames)
        }
      partNames.sort()

      foreach (partName in partNames) {
        if (partIdWhitelist != null && partIdWhitelist.findindex(@(v) startsWith(partName, v)) == null)
          continue
        let params = { name = partName }
        let info = ::dmViewer.getPartTooltipInfo(::dmViewer.getPartNameId(params), params)
        if (info.desc != "")
          blk[partName] <- stripTags($"{info.title}\n{info.desc}")
      }
      return blk.paramCount() != 0 ? { key = unit.name, value = blk } : null
    }
    onFinish = function() {
      ::dmViewer.isDebugBatchExportProcess = false
      ::dmViewer.toggle(DM_VIEWER_NONE)
    }
  })
}

function dbg_loading_brief(gm = GM_SINGLE_MISSION, missionName = "east_china_s01", slidesAmount = 0) {
  let missionBlk = get_meta_mission_info_by_gm_and_name(gm, missionName)
  if (!u.isDataBlock(missionBlk))
    return dlog($"Not found mission {missionName}") //warning disable: -dlog-warn

  let filePath = missionBlk?.mis_file
  if (filePath == null)
    return dlog("No mission blk filepath") //warning disable: -dlog-warn
  let fullBlk = blkFromPath(filePath)

  let briefing = fullBlk?.mission_settings.briefing
  if (!u.isDataBlock(briefing) || !briefing.blockCount())
    return dlog("Mission does not have briefing") //warning disable: -dlog-warn

  let briefingClone = DataBlock()
  if (slidesAmount <= 0)
    briefingClone.setFrom(briefing)
  else {
    local slidesLeft = slidesAmount
    let parts = briefing % "part"
    let partsClone = []
    for (local i = parts.len() - 1; i >= 0; i--) {
      let part = parts[i]
      let partClone = DataBlock()
      let slides = part % "slide"
      if (slides.len() <= slidesLeft) {
        partClone.setFrom(part)
        slidesLeft -= slides.len()
      }
      else
        for (local j = slides.len() - slidesLeft; j < slides.len(); j++) {
          let slide = slides[j]
          let slideClone = DataBlock()
          slideClone.setFrom(slide)
          partClone["slide"] <- slideClone
          slidesLeft--
        }

      partsClone.insert(0, partClone)
      if (slidesLeft <= 0)
        break
    }

    foreach (part in partsClone)
      briefingClone["part"] <- part
  }

  handlersManager.loadHandler(gui_handlers.LoadingBrief, { briefing = briefingClone })
}


function debug_show_units_by_loc_name(unitLocName, needIncludeNotInShop = false) {
  let units = shopSearchCore.findUnitsByLocName(unitLocName, true, needIncludeNotInShop)
  units.sort(function(a, b) { return a.name == b.name ? 0 : a.name < b.name ? -1 : 1 })

  let res = units.map(function(unit) {
    let locName = getUnitName(unit)
    let army = unit.unitType.getArmyLocName()
    let country = loc(getUnitCountry(unit))
    let rank = get_roman_numeral(unit?.rank ?? -1)
    let prem = (isUnitSpecial(unit) || isUnitGift(unit)) ? loc("shop/premiumVehicle/short") : ""
    let hidden = !unit.isInShop ? loc("controls/NA") : unit.isVisibleInShop() ? "" : loc("worldWar/hided_logs")
    return "".concat(unit.name, "; \"", locName, "\" (",
      ", ".join([ army, country, rank, prem, hidden ], true), ")")
  })

  foreach (line in res)
    dlog(line)
  return res.len()
}

function debug_show_unit(unitId) {
  let unit = getAircraftByName(unitId)
  if (!unit)
    return "Not found"
  showedUnit(unit)
  gui_start_decals()
  return "Done"
}

function debug_show_weapon(weaponName) {
  weaponName = getWeaponNameByBlkPath(weaponName)
  foreach (unit in getAllUnits()) {
    if (!unit.isInShop)
      continue
    let unitBlk = getFullUnitBlk(unit.name)
    let weapons = getUnitWeapons(unitBlk)
    foreach (weap in weapons)
      if (weaponName == getWeaponNameByBlkPath(weap?.blk ?? "")) {
        ::open_weapons_for_unit(unit)
        return $"{unit.name} / {weap.blk}"
      }
  }
  return null
}

function debug_get_last_userlogs(num = 1) {
  let total = get_user_logs_count()
  let res = []
  for (local i = total - 1; i > (total - num - 1); i--) {
    local blk = DataBlock()
    get_user_log_blk_body(i, blk)
    dlog($"print userlog {::getLogNameByType(blk.type)} {blk.id}")
    debugTableData(blk)
    res.append(blk)
  }
  return res
}


//





















function consoleAndDebugTableData(text, data) {
  console_print(text)
  debugTableData(data)
  return "Look in debug"
}

register_command(charAddAllItems, "debug.char_add_all_items")
register_command(switch_on_debug_debriefing_recount, "debug.switch_on_debug_debriefing_recount")
register_command(debug_reload_and_restart_debriefing, "debug.reload_and_restart_debriefing")
register_command(debug_debriefing_unlocks, "debug.debriefing_unlocks")
register_command(show_hotas_window_image, "debug.show_hotas_window_image")
register_command(debug_export_unit_weapons_descriptions, "debug.export_unit_weapons_descriptions")
register_command(debug_export_unit_xray_parts_descriptions, "debug.export_unit_xray_parts_descriptions")
register_command(@() dbg_loading_brief(), "debug.loading_brief")
register_command(dbg_loading_brief, "debug.loading_brief_custom")
register_command(debug_show_unit, "debug.show_unit")
register_command(debug_show_units_by_loc_name, "debug.show_units_by_loc_name")
register_command(debug_show_weapon, "debug.show_weapon")
register_command(debug_get_last_userlogs, "debug.get_last_userlogs")
register_command(@() consoleAndDebugTableData("userstatDescList: ", userstatDescList.value), "debug.userstat.desc_list")
register_command(@() consoleAndDebugTableData("userstatUnlocks: ", userstatUnlocks.value), "debug.userstat.unlocks")
register_command(@() consoleAndDebugTableData("userstatStats: ", userstatStats.value), "debug.userstat.stats")

//register_command(debug_unit_rent, "debug.unit_rent") //disabled as it changes global functions (and this wont work on import)
