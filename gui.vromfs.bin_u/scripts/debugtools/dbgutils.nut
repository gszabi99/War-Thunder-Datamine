//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let userstat = require("userstat")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format, split_by_chars } = require("string")
// warning disable: -file:forbidden-function

let { setGameLocalization, getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")
let { getLocalLanguage } = require("language")
let { reload } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let DataBlock  = require("DataBlock")
let { blkFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let dbgExportToFile = require("%scripts/debugTools/dbgExportToFile.nut")
let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let dirtyWordsFilter = require("%scripts/dirtyWordsFilter.nut")
let { getWeaponInfoText, getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getVideoModes } = require("%scripts/options/systemOptions.nut")
let { isWeaponAux, getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { userstatStats, userstatDescList, userstatUnlocks, refreshUserstatStats, refreshUserstatUnlocks
} = require("%scripts/userstat/userstat.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getDebriefingResult, setDebriefingResult } = require("%scripts/debriefing/debriefingFull.nut")
let applyRendererSettingsChange = require("%scripts/clientState/applyRendererSettingsChange.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { getUnitMassPerSecValue } = require("%scripts/unit/unitWeaponryInfo.nut")
let debugWnd = require("%scripts/debugTools/debugWnd.nut")
let animBg = require("%scripts/loading/animBg.nut")
let { register_command } = require("console")
let { get_meta_mission_info_by_gm_and_name } = require("guiMission")
let { hotasControlImagePath } = require("%scripts/controls/hotas.nut")
let { getAllTips } = require("%scripts/loading/loadingTips.nut")
let { startsWith, stripTags } = require("%sqstd/string.nut")
let { multiplyDaguiColorStr } = require("%sqDagui/daguiUtil.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_charserver_time_sec } = require("chard")
let { getUnitName, getUnitCountry, isUnitGift } = require("%scripts/unit/unitInfo.nut")
let { get_wpcost_blk } = require("blkGetters")
require("%scripts/debugTools/dbgLongestUnitTooltip.nut")
let { userIdInt64 } = require("%scripts/user/myUser.nut")

let function reload_dagui() {
  get_cur_gui_scene()?.resetGamepadMouseTarget()
  let res = reload(::reload_main_script_module)
  ::update_objects_under_windows_state(get_cur_gui_scene())
  dlog("Dagui reloaded")
  return res
}

let function _charAddAllItemsHelper(params) {
  if (params.currentIndex >= params.items.len())
    return
  let item = params.items[params.currentIndex]
  let blk = DataBlock()
  blk.setStr("what", "addItem")
  blk.setStr("item", item.id)
  blk.addInt("howmuch", params.count);
  let taskId = ::char_send_blk("dev_hack", blk)
  if (taskId == -1)
    return

  let __charAddAllItemsHelper = _charAddAllItemsHelper // for lambda capture

  ::add_bg_task_cb(taskId, function () {
    ++params.currentIndex
    if ((params.currentIndex == params.items.len() ||
         params.currentIndex % 10 == 0) &&
         params.currentIndex != 0)
      dlog(format("Adding items: %d/%d", params.currentIndex, params.items.len()))
    __charAddAllItemsHelper(params)
  })
}


let function charAddAllItems(count = 1) {
  let params = {
    items = ::ItemsManager.getItemsList()
    currentIndex = 0
    count
  }
  _charAddAllItemsHelper(params)
}

//must to be switched on before we get to debrifing.
//but after it you can restart derifing with full recalc by usual reload()
let function switch_on_debug_debriefing_recount() {
  if ("_stat_get_exp" in getroottable())
    return

  ::_stat_get_exp <- ::stat_get_exp
  ::_stat_get_exp_cache <- null
  ::stat_get_exp <- function() {
    ::_stat_get_exp_cache = ::_stat_get_exp() || ::_stat_get_exp_cache
    return ::_stat_get_exp_cache
  }
}

let function debug_reload_and_restart_debriefing() {
  let result = getDebriefingResult()
  reload_dagui()

  let canRecount = "_stat_get_exp" in getroottable()
  if (!canRecount)
    setDebriefingResult(result)

  ::gui_start_debriefingFull()
}

let function debug_debriefing_unlocks(unlocksAmount = 5) {
  ::gui_start_debriefingFull({ debugUnlocks = unlocksAmount })
}

let function show_hotas_window_image() {
    ::gui_start_image_wnd(hotasControlImagePath, 1.41)
}

let function debug_export_unit_weapons_descriptions() {
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
          blk[weapon.name + "_short"] <- getWeaponNameText(unit, false, weapon.name, ", ")
          local rowsList = split_by_chars(getWeaponInfoText(unit,
            { isPrimary = false, weaponPreset = weapon.name }), "\n")
          foreach (row in rowsList)
            blk[weapon.name] <- row
          rowsList = split_by_chars(getWeaponInfoText(unit,
            { isPrimary = false, weaponPreset = weapon.name, detail = INFO_DETAIL.EXTENDED }), "\n")
          foreach (row in rowsList)
            blk[weapon.name + "_extended"] <- row
          rowsList = split_by_chars(getWeaponInfoText(unit,
            { weaponPreset = weapon.name, detail = INFO_DETAIL.FULL }), "\n")
          foreach (row in rowsList)
            blk[weapon.name + "_full"] <- row
          blk[$"{weapon.name}_massPerSec"] <- getUnitMassPerSecValue(unit, true, weapon.name)
          blk[$"{weapon.name}_bombsNbr"] <- weapon.bombsNbr
        }
      return { key = unit.name, value = blk }
    }
  })
}

let function debug_export_unit_xray_parts_descriptions(partIdWhitelist = null) {
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
          blk[partName] <- stripTags(info.title + "\n" + info.desc)
      }
      return blk.paramCount() != 0 ? { key = unit.name, value = blk } : null
    }
    onFinish = function() {
      ::dmViewer.isDebugBatchExportProcess = false
      ::dmViewer.toggle(DM_VIEWER_NONE)
    }
  })
}

let function gui_do_debug_unlock() {
  ::debug_unlock_all();
  ::is_debug_mode_enabled = true
  ::update_all_units();
  ::add_warpoints(500000, false);
  broadcastEvent("DebugUnlockEnabled")
}

let function dbg_loading_brief(gm = GM_SINGLE_MISSION, missionName = "east_china_s01", slidesAmount = 0) {
  let missionBlk = get_meta_mission_info_by_gm_and_name(gm, missionName)
  if (!u.isDataBlock(missionBlk))
    return dlog("Not found mission " + missionName) //warning disable: -dlog-warn

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


let function debug_show_units_by_loc_name(unitLocName, needIncludeNotInShop = false) {
  let units = shopSearchCore.findUnitsByLocName(unitLocName, true, needIncludeNotInShop)
  units.sort(function(a, b) { return a.name == b.name ? 0 : a.name < b.name ? -1 : 1 })

  let res = units.map(function(unit) {
    let locName = getUnitName(unit)
    let army = unit.unitType.getArmyLocName()
    let country = loc(getUnitCountry(unit))
    let rank = get_roman_numeral(unit?.rank ?? -1)
    let prem = (::isUnitSpecial(unit) || isUnitGift(unit)) ? loc("shop/premiumVehicle/short") : ""
    let hidden = !unit.isInShop ? loc("controls/NA") : unit.isVisibleInShop() ? "" : loc("worldWar/hided_logs")
    return unit.name + "; \"" + locName + "\" (" + ", ".join([ army, country, rank, prem, hidden ], true) + ")"
  })

  foreach (line in res)
    dlog(line)
  return res.len()
}

let function debug_show_unit(unitId) {
  let unit = getAircraftByName(unitId)
  if (!unit)
    return "Not found"
  showedUnit(unit)
  ::gui_start_decals()
  return "Done"
}

let function debug_show_weapon(weaponName) {
  weaponName = getWeaponNameByBlkPath(weaponName)
  foreach (unit in getAllUnits()) {
    if (!unit.isInShop)
      continue
    let unitBlk = ::get_full_unit_blk(unit.name)
    let weapons = getUnitWeapons(unitBlk)
    foreach (weap in weapons)
      if (weaponName == getWeaponNameByBlkPath(weap?.blk ?? "")) {
        ::open_weapons_for_unit(unit)
        return $"{unit.name} / {weap.blk}"
      }
  }
  return null
}

let function debug_change_language(isNext = true) {
  let list = getGameLocalizationInfo()
  let curLang = getLocalLanguage()
  let curIdx = list.findindex(@(l) l.id == curLang) ?? 0
  let newIdx = curIdx + (isNext ? 1 : -1 + list.len())
  let newLang = list[newIdx % list.len()]
  setGameLocalization(newLang.id, true, false)
  dlog("Set language: " + newLang.id)
}

let function debug_change_resolution(shouldIncrease = true) {
  let curResolution = ::getSystemConfigOption("video/resolution")
  let list = getVideoModes(curResolution, false)
  let curIdx = list.indexof(curResolution) || 0
  let newIdx = clamp(curIdx + (shouldIncrease ? 1 : -1), 0, list.len() - 1)
  let newResolution = list[newIdx]
  let done = @() dlog("Set resolution: " + newResolution +
    " (" + screen_width() + "x" + screen_height() + ")")
  if (newResolution == curResolution)
    return done()
  ::setSystemConfigOption("video/resolution", newResolution)
  applyRendererSettingsChange(true, false, function() {
    done()
  })
}

let function debug_multiply_color(colorStr, multiplier) {
  let res = multiplyDaguiColorStr(colorStr, multiplier)
  ::copy_to_clipboard(res)
  return res
}

let function debug_get_last_userlogs(num = 1) {
  let total = ::get_user_logs_count()
  let res = []
  for (local i = total - 1; i > (total - num - 1); i--) {
    local blk = DataBlock()
    ::get_user_log_blk_body(i, blk)
    dlog("print userlog " + ::getLogNameByType(blk.type) + " " + blk.id)
    debugTableData(blk)
    res.append(blk)
  }
  return res
}

let function to_pixels_float(value) {
  return to_pixels("(" + value + ") * 1000000") / 1000000.0
}

let function debug_check_dirty_words(path = null) {
  let blk = DataBlock()
  blk.load(path || "debugDirtyWords.blk")
  dirtyWordsFilter.setDebugLogFunc(log)
  local failed = 0
  for (local i = 0; i < blk.paramCount(); i++) {
    let text = blk.getParamValue(i)
    let filteredText = dirtyWordsFilter.checkPhrase(text)
    if (text == filteredText) {
      log("DIRTYWORDS: PASSED " + text)
      failed++
    }
  }
  dirtyWordsFilter.setDebugLogFunc(null)
  dlog("DIRTYWORDS: FINISHED, checked " + blk.paramCount() + ", failed check " + failed)
}

let function debug_unit_rent(unitId = null, seconds = 60) {
  if (!("_debug_unit_rent" in getroottable())) {
    ::_debug_unit_rent <- {}
    ::_shop_is_unit_rented <- ::shop_is_unit_rented
    ::_rented_units_get_last_max_full_rent_time <- ::rented_units_get_last_max_full_rent_time
    ::_rented_units_get_expired_time_sec <- ::rented_units_get_expired_time_sec
    ::shop_is_unit_rented = @(id) (::_debug_unit_rent?[id] ? true : ::_shop_is_unit_rented(id))
    ::rented_units_get_last_max_full_rent_time = @(id) (::_debug_unit_rent?[id]?.time ??
      ::_rented_units_get_last_max_full_rent_time(id))
    ::rented_units_get_expired_time_sec = function(id) {
      if (!::_debug_unit_rent?[id])
        return ::_rented_units_get_expired_time_sec(id)
      let remain = ::_debug_unit_rent[id].expire - get_charserver_time_sec()
      if (remain <= 0)
        delete ::_debug_unit_rent[id]
      return remain
    }
  }

  if (unitId) {
    ::_debug_unit_rent[unitId] <- { time = seconds, expire = get_charserver_time_sec() + seconds }
    broadcastEvent("UnitRented", { unitName = unitId })
  }
  else
    ::_debug_unit_rent.clear()
}

let function debug_tips_list() {
  debugWnd("%gui/debugTools/dbgTipsList.tpl",
    { tipsList = getAllTips().map(@(value) { value = value }) })
}

let function debug_get_skyquake_path() {
  let dir = ::get_exe_dir()
  let idx = dir.indexof("/skyquake/")
  return idx != null ? dir.slice(0, idx + 9) : ""
}

//






















let function consoleAndDebugTableData(text, data) {
  console_print(text)
  debugTableData(data)
  return "Look in debug"
}

let dbgFocusData = persist("dbgFocusData", @() { debugFocusTask = -1, prevSelObj = null })
let function debug_focus(needShow = true) {
  if (!needShow) {
    if (dbgFocusData.debugFocusTask != -1)
      ::periodic_task_unregister(dbgFocusData.debugFocusTask)
    dbgFocusData.debugFocusTask = -1
    return "Switch off debug focus"
  }

  if (dbgFocusData.debugFocusTask == -1)
    dbgFocusData.debugFocusTask = ::periodic_task_register({},
      function(_) {
        let newObj = get_cur_gui_scene().getSelectedObject()
        let { prevSelObj } = dbgFocusData
        let isSame = newObj == prevSelObj
          || (newObj != null && (prevSelObj?.isValid() ?? true) && newObj.isEqual(prevSelObj))
        if (isSame)
          return
        let text = $"Cur focused object = {newObj?.tag} / {newObj?.id}"
        dlog(text)
        console_print(text)
        dbgFocusData.prevSelObj = newObj
      },
      1)

  dbgFocusData.prevSelObj = get_cur_gui_scene().getSelectedObject()
  let { prevSelObj } = dbgFocusData
  let text = $"Cur focused object = {prevSelObj?.tag} / {prevSelObj?.id}"
  dlog(text)
  return text
}

if (dbgFocusData.debugFocusTask != -1) {
  dbgFocusData.debugFocusTask = -1
  dbgFocusData.prevSelObj = null
  debug_focus()
}

let debug_open_url = @() ::gui_modal_editbox_wnd({
  title = "Enter url"
  allowEmpty = false
  okFunc = openUrl
})

register_command(reload_dagui, "debug.reload_dagui")
register_command(charAddAllItems, "debug.char_add_all_items")
register_command(switch_on_debug_debriefing_recount, "debug.switch_on_debug_debriefing_recount")
register_command(debug_reload_and_restart_debriefing, "debug.reload_and_restart_debriefing")
register_command(debug_debriefing_unlocks, "debug.debriefing_unlocks")
register_command(show_hotas_window_image, "debug.show_hotas_window_image")
register_command(debug_export_unit_weapons_descriptions, "debug.export_unit_weapons_descriptions")
register_command(debug_export_unit_xray_parts_descriptions, "debug.export_unit_xray_parts_descriptions")
register_command(gui_do_debug_unlock, "debug.gui_do_debug_unlock")
register_command(@() dbg_loading_brief(), "debug.loading_brief")
register_command(dbg_loading_brief, "debug.loading_brief_custom")
register_command(debug_show_unit, "debug.show_unit")
register_command(debug_show_units_by_loc_name, "debug.show_units_by_loc_name")
register_command(debug_show_weapon, "debug.show_weapon")
register_command(@() debug_change_language(), "debug.change_language_to_next")
register_command(@() debug_change_language(false), "debug.change_language_to_prev")
register_command(@() debug_change_resolution(), "debug.change_resolution_to_next")
register_command(@() debug_change_resolution(false), "debug.change_resolution_to_prev")
register_command(debug_multiply_color, "debug.multiply_color")
register_command(debug_get_last_userlogs, "debug.get_last_userlogs")
register_command(@(value) dlog(to_pixels(value)), "debug.to_pixels")
register_command(@(value) dlog(to_pixels_float(value)), "debug.to_pixels_float")
register_command(debug_check_dirty_words, "debug.check_dirty_words")
register_command(debug_unit_rent, "debug.unit_rent")
register_command(debug_tips_list, "debug.tips_list")
register_command(@() consoleAndDebugTableData("userstatDescList: ", userstatDescList.value), "debug.userstat.desc_list")
register_command(@() consoleAndDebugTableData("userstatUnlocks: ", userstatUnlocks.value), "debug.userstat.unlocks")
register_command(@() consoleAndDebugTableData("userstatStats: ", userstatStats.value), "debug.userstat.stats")
register_command(animBg.debugLoad, "debug.load_anim_bg")
register_command(debug_focus, "debug.focus")
register_command(debug_open_url, "debug.open_url")

return {
  debug_get_skyquake_path
  gui_do_debug_unlock
  debug_open_url
}