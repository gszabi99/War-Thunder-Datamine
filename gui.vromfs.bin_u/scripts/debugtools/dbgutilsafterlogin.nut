
from "%scripts/dagui_natives.nut" import rented_units_get_expired_time_sec, get_user_logs_count,
  get_user_log_blk_body, shop_is_unit_rented, rented_units_get_last_max_full_rent_time, char_send_blk,
  save_online_single_job, set_auto_refill, get_auto_refill
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import INFO_DETAIL, SAVE_WEAPON_JOB_DIGIT

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isDataBlock } = require("%sqStdLibs/helpers/u.nut")
let userstat = require("userstat")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format, split_by_chars } = require("string")
let DataBlock  = require("DataBlock")
let { blkFromPath } = require("%sqstd/datablock.nut")
let dbgExportToFile = require("%globalScripts/debugTools/dbgExportToFile.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { getWeaponInfoText, getWeaponNameText, makeWeaponInfoData } = require("%scripts/weaponry/weaponryDescription.nut")
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
let { addTask, addBgTaskCb } = require("%scripts/tasker.nut")
let { getLogNameByType } = require("%scripts/userLog/userlogUtils.nut")
let { open_weapons_for_unit } = require("%scripts/weaponry/weaponryActions.nut")
let { getItemsList } = require("%scripts/items/itemsManager.nut")
let { startLogout } = require("%scripts/login/logout.nut")

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

  let __charAddAllItemsHelper = _charAddAllItemsHelper 

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
    items = getItemsList()
    currentIndex = 0
    count
  }
  _charAddAllItemsHelper(params)
}



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
          let weaponInfoParams = { isPrimary = false, weaponPreset = weapon.name }
          let weaponInfoData = makeWeaponInfoData(unit, weaponInfoParams)
          local rowsList = split_by_chars(getWeaponInfoText(unit, weaponInfoData), "\n")
          foreach (row in rowsList)
            blk[weapon.name] <- row

          let weaponInfoParamsExtended = { isPrimary = false, weaponPreset = weapon.name, detail = INFO_DETAIL.EXTENDED }
          let weaponInfoDataExtended = makeWeaponInfoData(unit, weaponInfoParamsExtended)
          rowsList = split_by_chars(getWeaponInfoText(unit, weaponInfoDataExtended), "\n")
          foreach (row in rowsList)
            blk[$"{weapon.name}_extended"] <- row

          let weaponInfoParamsFull = { weaponPreset = weapon.name, detail = INFO_DETAIL.FULL }
          let weaponInfoDataFull = makeWeaponInfoData(unit, weaponInfoParamsFull)
          rowsList = split_by_chars(getWeaponInfoText(unit, weaponInfoDataFull), "\n")

          foreach (row in rowsList)
            blk[$"{weapon.name}_full"] <- row
          blk[$"{weapon.name}_massPerSec"] <- getUnitMassPerSecValue(unit, true, weapon.name)
          blk[$"{weapon.name}_bombsNbr"] <- weapon.bombsNbr
        }
      return { key = unit.name, value = blk }
    }
  })
}

function dbg_loading_brief(gm = GM_SINGLE_MISSION, missionName = "east_china_s01", slidesAmount = 0) {
  let missionBlk = get_meta_mission_info_by_gm_and_name(gm, missionName)
  if (!isDataBlock(missionBlk))
    return dlog($"Not found mission {missionName}") 

  let filePath = missionBlk?.mis_file
  if (filePath == null)
    return dlog("No mission blk filepath") 
  let fullBlk = blkFromPath(filePath)

  let briefing = fullBlk?.mission_settings.briefing
  if (!isDataBlock(briefing) || !briefing.blockCount())
    return dlog("Mission does not have briefing") 

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
  showedUnit.set(unit)
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
        open_weapons_for_unit(unit)
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
    dlog($"print userlog {getLogNameByType(blk.type)} {blk.id}")
    debugTableData(blk)
    res.append(blk)
  }
  return res
}
























function consoleAndDebugTableData(text, data) {
  console_print(text)
  debugTableData(data)
  return "Look in debug"
}

function sendActionToCharAndStartLogout() {
  startLogout()
  let mode = 0
  let curValue = get_auto_refill(mode)
  set_auto_refill(mode, !curValue)
  addTask(save_online_single_job(SAVE_WEAPON_JOB_DIGIT), { showProgressBox = true })
}

register_command(charAddAllItems, "debug.char_add_all_items")
register_command(switch_on_debug_debriefing_recount, "debug.switch_on_debug_debriefing_recount")
register_command(debug_reload_and_restart_debriefing, "debug.reload_and_restart_debriefing")
register_command(debug_debriefing_unlocks, "debug.debriefing_unlocks")
register_command(show_hotas_window_image, "debug.show_hotas_window_image")
register_command(debug_export_unit_weapons_descriptions, "debug.export_unit_weapons_descriptions")
register_command(@() dbg_loading_brief(), "debug.loading_brief")
register_command(dbg_loading_brief, "debug.loading_brief_custom")
register_command(debug_show_unit, "debug.show_unit")
register_command(debug_show_units_by_loc_name, "debug.show_units_by_loc_name")
register_command(debug_show_weapon, "debug.show_weapon")
register_command(debug_get_last_userlogs, "debug.get_last_userlogs")
register_command(@() consoleAndDebugTableData("userstatDescList: ", userstatDescList.value), "debug.userstat.desc_list")
register_command(@() consoleAndDebugTableData("userstatUnlocks: ", userstatUnlocks.value), "debug.userstat.unlocks")
register_command(@() consoleAndDebugTableData("userstatStats: ", userstatStats.value), "debug.userstat.stats")
register_command(sendActionToCharAndStartLogout, "debug.send_action_to_char_and_start_logout")


