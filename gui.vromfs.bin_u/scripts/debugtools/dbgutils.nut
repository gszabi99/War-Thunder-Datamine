// warning disable: -file:forbidden-function

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

require("%scripts/debugTools/dbgLongestUnitTooltip.nut")

::callstack <- dagor.debug_dump_stack

::reload <- function reload()
{
  ::get_cur_gui_scene()?.resetGamepadMouseTarget()
  let res = ::g_script_reloader.reload(::reload_main_script_module)
  ::update_objects_under_windows_state(::get_cur_gui_scene())
  return res
}

::get_stack_string <- function get_stack_string(level = 2)
{
  return ::toString(getstackinfos(level), 2)
}

::print_func_and_enum_state_string <- function print_func_and_enum_state_string(enumString, currentState)
{
  dlog(::getstackinfos(2).func + " " + ::getEnumValName(enumString, currentState))
}

::charAddAllItems <- function charAddAllItems(count = 1)
{
  let params = {
    items = ::ItemsManager.getItemsList()
    currentIndex = 0
    count = count
  }
  ::_charAddAllItemsHelper(params)
}

::_charAddAllItemsHelper <- function _charAddAllItemsHelper(params)
{
  if (params.currentIndex >= params.items.len())
    return
  let item = params.items[params.currentIndex]
  let blk = ::DataBlock()
  blk.setStr("what", "addItem")
  blk.setStr("item", item.id)
  blk.addInt("howmuch", params.count);
  let taskId = ::char_send_blk("dev_hack", blk)
  if (taskId == -1)
    return
  ::add_bg_task_cb(taskId, (@(params) function () {
    ++params.currentIndex
    if ((params.currentIndex == params.items.len() ||
         params.currentIndex % 10 == 0) &&
         params.currentIndex != 0)
      ::dlog(::format("Adding items: %d/%d", params.currentIndex, params.items.len()))
    _charAddAllItemsHelper(params)
  })(params))
}

//must to be switched on before we get to debrifing.
//but after it you can restart derifing with full recalc by usual reload()
::switch_on_debug_debriefing_recount <- function switch_on_debug_debriefing_recount()
{
  if ("_stat_get_exp" in ::getroottable())
    return

  ::_stat_get_exp <- ::stat_get_exp
  ::_stat_get_exp_cache <- null
  ::stat_get_exp <- function()
  {
    ::_stat_get_exp_cache = ::_stat_get_exp() || ::_stat_get_exp_cache
    return ::_stat_get_exp_cache
  }
}

::debug_reload_and_restart_debriefing <- function debug_reload_and_restart_debriefing()
{
  let result = getDebriefingResult()
  ::reload()

  let canRecount = "_stat_get_exp" in ::getroottable()
  if (!canRecount)
    setDebriefingResult(result)

  gui_start_debriefingFull()
}

::debug_debriefing_unlocks <- function debug_debriefing_unlocks(unlocksAmount = 5)
{
  ::gui_start_debriefingFull({ debugUnlocks = unlocksAmount })
}

::debug_trophy_rewards_list <- function debug_trophy_rewards_list(id = "shop_test_multiple_types_reward") {
  let trophy = ::ItemsManager.findItemById(id)
  local content = trophy.getContent()
    .map(@(i) ::buildTableFromBlk(i))
    .sort(::trophyReward.rewardsSortComparator)

  ::gui_start_open_trophy_rewards_list({ rewardsArray = content })
}

::debug_get_every_day_login_award_userlog <- function debug_get_every_day_login_award_userlog(skip = 0, launchWindow = true)
{
  let total = ::get_user_logs_count()
  for (local i = total-1; i > 0; i--)
  {
    let blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk.type == ::EULT_CHARD_AWARD && ::getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward")
    {
      if (skip > 0)
      {
        skip--
        continue
      }

      if (launchWindow)
      {
        let shownIdx = ::shown_userlog_notifications.indexof(blk?.id)
        if (shownIdx != null)
          ::shown_userlog_notifications.remove(shownIdx)
        ::gui_start_show_login_award(blk)
      }
      else
      {
        dlog("PRINT EVERY DAY LOGIN AWARD")
        ::debugTableData(blk)
      }
      return
    }
  }
  dlog("!!!! NOT FOUND ANY EVERY DAY LOGIN AWARD")
}

::show_hotas_window_image <- function show_hotas_window_image()
{
  ::gui_start_image_wnd(::loc("thrustmaster_tflight_hotas_4_controls_image", ""), 1.41)
}

::debug_export_unit_weapons_descriptions <- function debug_export_unit_weapons_descriptions()
{
  dbgExportToFile.export({
    resultFilePath = "export/unitsWeaponry.blk"
    itemsPerFrame = 10
    list = function() {
      let res = []
      let wpCost = ::get_wpcost_blk()
      for (local i = 0; i < wpCost.blockCount(); i++) {
        let unit = ::getAircraftByName(wpCost.getBlock(i).getBlockName())
        if (unit?.isInShop)
          res.append(unit)
      }
      return res
    }()
    itemProcessFunc = function(unit) {
      let blk = ::DataBlock()
      foreach(weapon in unit.getWeapons())
        if (!isWeaponAux(weapon))
        {
          blk[weapon.name + "_short"] <- getWeaponNameText(unit, false, weapon.name, ", ")
          local rowsList = ::split(getWeaponInfoText(unit,
            { isPrimary = false, weaponPreset = weapon.name }), "\n")
          foreach(row in rowsList)
            blk[weapon.name] <- row
          rowsList = ::split(getWeaponInfoText(unit,
            { isPrimary = false, weaponPreset = weapon.name, detail = INFO_DETAIL.EXTENDED }), "\n")
          foreach(row in rowsList)
            blk[weapon.name + "_extended"] <- row
          rowsList = ::split(getWeaponInfoText(unit,
            { weaponPreset = weapon.name, detail = INFO_DETAIL.FULL }), "\n")
          foreach(row in rowsList)
            blk[weapon.name + "_full"] <- row
        }
      return { key = unit.name, value = blk }
    }
  })
}

::debug_export_unit_xray_parts_descriptions <- function debug_export_unit_xray_parts_descriptions(partIdWhitelist = null)
{
  ::dmViewer.isDebugBatchExportProcess = true
  ::dmViewer.toggle(::DM_VIEWER_XRAY)
  dbgExportToFile.export({
    resultFilePath = "export/unitsXray.blk"
    itemsPerFrame = 10
    list = function() {
      let res = []
      let wpCost = ::get_wpcost_blk()
      for (local i = 0; i < wpCost.blockCount(); i++) {
        let unit = ::getAircraftByName(wpCost.getBlock(i).getBlockName())
        if (unit?.isInShop)
          res.append(unit)
      }
      return res
    }()
    itemProcessFunc = function(unit) {
      let blk = ::DataBlock()

      ::dmViewer.updateUnitInfo(unit.name)
      let partNames = []
      let damagePartsBlk = ::dmViewer.unitBlk?.DamageParts
      if (damagePartsBlk)
        for (local b = 0; b < damagePartsBlk.blockCount(); b++)
        {
          let partsBlk = damagePartsBlk.getBlock(b)
          for (local p = 0; p < partsBlk.blockCount(); p++)
            ::u.appendOnce(partsBlk.getBlock(p).getBlockName(), partNames)
        }
      partNames.sort()

      foreach (partName in partNames)
      {
        if (partIdWhitelist != null && partIdWhitelist.findindex(@(v) ::g_string.startsWith(partName, v)) == null)
          continue
        let params = { name = partName }
        let info = ::dmViewer.getPartTooltipInfo(::dmViewer.getPartNameId(params), params)
        if (info.desc != "")
          blk[partName] <- ::g_string.stripTags(info.title + "\n" + info.desc)
      }
      return blk.paramCount() != 0 ? { key = unit.name, value = blk } : null
    }
    onFinish = function() {
      ::dmViewer.isDebugBatchExportProcess = false
      ::dmViewer.toggle(::DM_VIEWER_NONE)
    }
  })
}

::gui_do_debug_unlock <- function gui_do_debug_unlock()
{
  ::debug_unlock_all();
  ::is_debug_mode_enabled = true
  ::update_all_units();
  ::add_warpoints(500000, false);
  ::broadcastEvent("DebugUnlockEnabled")
}

::dbg_loading_brief <- function dbg_loading_brief(missionName = "malta_ship_mission", slidesAmount = 0)
{
  let missionBlk = ::get_meta_mission_info_by_name(missionName)
  if (!::u.isDataBlock(missionBlk))
    return dlog("Not found mission " + missionName) //warning disable: -dlog-warn

  let filePath = missionBlk?.mis_file
  if (filePath==null)
    return dlog("No mission blk filepath") //warning disable: -dlog-warn
  let fullBlk = blkFromPath(filePath)

  let briefing = fullBlk?.mission_settings.briefing
  if (!::u.isDataBlock(briefing) || !briefing.blockCount())
    return dlog("Mission does not have briefing") //warning disable: -dlog-warn

  let briefingClone = ::DataBlock()
  if (slidesAmount <= 0)
    briefingClone.setFrom(briefing)
  else
  {
    local slidesLeft = slidesAmount
    let parts = briefing % "part"
    let partsClone = []
    for(local i = parts.len()-1; i >= 0; i--)
    {
      let part = parts[i]
      let partClone = ::DataBlock()
      let slides = part % "slide"
      if (slides.len() <= slidesLeft)
      {
        partClone.setFrom(part)
        slidesLeft -= slides.len()
      }
      else
        for(local j = slides.len()-slidesLeft; j < slides.len(); j++)
        {
          let slide = slides[j]
          let slideClone = ::DataBlock()
          slideClone.setFrom(slide)
          partClone["slide"] <- slideClone
          slidesLeft--
        }

      partsClone.insert(0, partClone)
      if (slidesLeft <= 0)
        break
    }

    foreach(part in partsClone)
      briefingClone["part"] <- part
  }

  ::handlersManager.loadHandler(::gui_handlers.LoadingBrief, { briefing = briefingClone })
}

::dbg_content_patch_open <- function dbg_content_patch_open(isProd = false)
{
  let restoreData = {
    start_content_patch_download = start_content_patch_download
    stop_content_patch_download = stop_content_patch_download
  }

  ::stop_content_patch_download = function() {
    foreach(name, func in restoreData)
      getroottable()[name] = func
  }

  local updaterData = {
                        handler = null
                        callback = null
                        eta_sec = 100000
                        percent = 0
                        onUpdate = function(obj = null, dt = null)
                        {
                          eta_sec -= 100
                          if(handler.stage == -1)
                            callback.call(handler, ::UPDATER_CB_STAGE, ::UPDATER_DOWNLOADING, 0, 0)
                          if(percent < 100)
                            percent += 0.1
                          callback.call(handler, ::UPDATER_CB_PROGRESS, percent, ::math.frnd() * 112048 + 1360000, eta_sec)
                        }
                      }

  ::start_content_patch_download = function(configPath, handler, updaterCallback) {
    updaterData.handler = handler
    updaterData.callback = updaterCallback

    let fooTimerObj = "timer { id:t = 'debug_loading_timer'; timer_handler_func:t = 'onUpdate' }"
    handler.guiScene.appendWithBlk(handler.scene, fooTimerObj, null)
    let curTimerObj = handler.scene.findObject("debug_loading_timer")
    curTimerObj.setUserData(updaterData)
  }

  ::gui_start_modal_wnd(::gui_handlers.PS4UpdaterModal,
  {
    configPath = isProd ? "/app0/ps4/updater.blk" : "/app0/ps4/updater_dev.blk"
  })

  ::dbg_ps4updater_close <- (@(updaterData) function() {
    if( ! updaterData || ! updaterData.handler || ! updaterData.callback)
      return
    updaterData.callback.call(updaterData.handler, ::UPDATER_CB_FINISH, 0, 0, 0)
  })(updaterData)
}

::debug_show_units_by_loc_name <- function debug_show_units_by_loc_name(unitLocName, needIncludeNotInShop = false)
{
  let units = shopSearchCore.findUnitsByLocName(unitLocName, true, needIncludeNotInShop)
  units.sort(function(a, b) { return a.name == b.name ? 0 : a.name < b.name ? -1 : 1 })

  let res = ::u.map(units, function(unit) {
    let locName = ::getUnitName(unit)
    let army = unit.unitType.getArmyLocName()
    let country = ::loc(::getUnitCountry(unit))
    let rank = ::get_roman_numeral(unit?.rank ?? -1)
    let prem = (::isUnitSpecial(unit) || ::isUnitGift(unit)) ? ::loc("shop/premiumVehicle/short") : ""
    let hidden = !unit.isInShop ? ::loc("controls/NA") : unit.isVisibleInShop() ? "" : ::loc("worldWar/hided_logs")
    return unit.name + "; \"" + locName + "\" (" + ::g_string.implode([ army, country, rank, prem, hidden ], ", ") + ")"
  })

  foreach (line in res)
    dlog(line)
  return res.len()
}

::debug_show_unit <- function debug_show_unit(unitId)
{
  let unit = ::getAircraftByName(unitId)
  if (!unit)
    return "Not found"
  showedUnit(unit)
  ::gui_start_decals()
  return "Done"
}

::debug_show_weapon <- function debug_show_weapon(weaponName)
{
  weaponName = getWeaponNameByBlkPath(weaponName)
  foreach (u in ::all_units)
  {
    if (!u.isInShop)
      continue
    let unitBlk = ::get_full_unit_blk(u.name)
    let weapons = getUnitWeapons(unitBlk)
    foreach (weap in weapons)
      if (weaponName == getWeaponNameByBlkPath(weap?.blk ?? ""))
      {
        ::open_weapons_for_unit(u)
        return $"{u.name} / {weap.blk}"
      }
  }
  return null
}

::debug_change_language <- function debug_change_language(isNext = true)
{
  let list = ::g_language.getGameLocalizationInfo()
  let curLang = ::get_current_language()
  let curIdx = list.findindex( @(l) l.id == curLang ) ?? 0
  let newIdx = curIdx + (isNext ? 1 : -1 + list.len())
  let newLang = list[newIdx % list.len()]
  ::g_language.setGameLocalization(newLang.id, true, false)
  dlog("Set language: " + newLang.id)
}

::debug_change_resolution <- function debug_change_resolution(shouldIncrease = true)
{
  let curResolution = ::getSystemConfigOption("video/resolution")
  let list = getVideoModes(curResolution, false)
  let curIdx = list.indexof(curResolution) || 0
  let newIdx = ::clamp(curIdx + (shouldIncrease ? 1 : -1), 0, list.len() - 1)
  let newResolution = list[newIdx]
  let done = @() dlog("Set resolution: " + newResolution +
    " (" + screen_width() + "x" + screen_height() + ")")
  if (newResolution == curResolution)
    return done()
  ::setSystemConfigOption("video/resolution", newResolution)
  applyRendererSettingsChange(true, false, function() {
    ::call_darg("updateExtWatched", { resolution = newResolution })
    done()
  })
}

::debug_multiply_color <- function debug_multiply_color(colorStr, multiplier)
{
  let res = ::g_dagui_utils.multiplyDaguiColorStr(colorStr, multiplier)
  ::copy_to_clipboard(res)
  return res
}

::debug_get_last_userlogs <- function debug_get_last_userlogs(num = 1)
{
  let total = ::get_user_logs_count()
  let res = []
  for (local i = total - 1; i > (total - num - 1); i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    ::dlog("print userlog " + ::getLogNameByType(blk.type) + " " + blk.id)
    ::debugTableData(blk)
    res.append(blk)
  }
  return res
}

::to_pixels <- function to_pixels(value)
{
  return ::g_dagui_utils.toPixels(::get_cur_gui_scene(), value)
}

::to_pixels_float <- function to_pixels_float(value)
{
  return ::to_pixels("(" + value + ") * 1000000") / 1000000.0
}

::perform_delayed <- function perform_delayed(func, handler = null)
{
  handler = handler ?? ::get_cur_base_gui_handler()
  ::get_gui_scene().performDelayed(handler, func)
}

::debug_reset_unseen <- function debug_reset_unseen()
{
  require("%scripts/seen/seenList.nut").clearAllSeenData()
}

::debug_check_dirty_words <- function debug_check_dirty_words(path = null)
{
  let blk = ::DataBlock()
  blk.load(path || "debugDirtyWords.blk")
  dirtyWordsFilter.setDebugLogFunc(::dagor.debug)
  local failed = 0
  for (local i = 0; i < blk.paramCount(); i++)
  {
    let text = blk.getParamValue(i)
    let filteredText = dirtyWordsFilter.checkPhrase(text)
    if (text == filteredText)
    {
      ::dagor.debug("DIRTYWORDS: PASSED " + text)
      failed++
    }
  }
  dirtyWordsFilter.setDebugLogFunc(null)
  dlog("DIRTYWORDS: FINISHED, checked " + blk.paramCount() + ", failed check " + failed)
}

::debug_unit_rent <- function debug_unit_rent(unitId = null, seconds = 60)
{
  if (!("_debug_unit_rent" in ::getroottable()))
  {
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
      let remain = ::_debug_unit_rent[id].expire - ::get_charserver_time_sec()
      if (remain <= 0)
        delete ::_debug_unit_rent[id]
      return remain
    }
  }

  if (unitId)
  {
    ::_debug_unit_rent[unitId] <- { time = seconds, expire = ::get_charserver_time_sec() + seconds }
    ::broadcastEvent("UnitRented", { unitName = unitId })
  }
  else
    ::_debug_unit_rent.clear()
}

::debug_tips_list <- function debug_tips_list() {
  debug_wnd("%gui/debugTools/dbgTipsList.tpl",
    {tipsList = ::g_tips.getAllTips().map(@(value) { value = value })})
}

::debug_get_skyquake_path <- function debug_get_skyquake_path() {
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
::userstat_debug_desc_list <- @() consoleAndDebugTableData("userstatDescList: ", userstatDescList.value)
::userstat_debug_unlocks <- @() consoleAndDebugTableData("userstatUnlocks: ", userstatUnlocks.value)
::userstat_debug_stats <- @() consoleAndDebugTableData("userstatStats: ", userstatStats.value)

::debug_load_anim_bg <- require("%scripts/loading/animBg.nut").debugLoad

let dbgFocusData = persist("dbgFocusData", @() { debugFocusTask = -1, prevSelObj = null })
::debug_focus <- function debug_focus(needShow = true) {
  if (!needShow) {
    if (dbgFocusData.debugFocusTask != -1)
      ::periodic_task_unregister(dbgFocusData.debugFocusTask)
    dbgFocusData.debugFocusTask = -1
    return "Switch off debug focus"
  }

  if (dbgFocusData.debugFocusTask == -1)
    dbgFocusData.debugFocusTask = ::periodic_task_register({},
      function(_) {
        let newObj = ::get_cur_gui_scene().getSelectedObject()
        let { prevSelObj } = dbgFocusData
        let isSame = newObj == prevSelObj
          || (newObj != null && (prevSelObj?.isValid() ?? true) && newObj.isEqual(prevSelObj))
        if (isSame)
          return
        let text = $"Cur focused object = {newObj?.tag} / {newObj?.id}"
        dlog(text)
        ::dagor.console_print(text)
        dbgFocusData.prevSelObj = newObj
      },
      1)

  dbgFocusData.prevSelObj = ::get_cur_gui_scene().getSelectedObject()
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

::debug_open_url <- @() ::gui_modal_editbox_wnd({
  title = "Enter url"
  allowEmpty = false
  okFunc = openUrl
})

::debug_show_steam_rate_wnd <- @() require("%scripts/user/suggestionRateGame.nut").tryOpenSteamRateReview(true)