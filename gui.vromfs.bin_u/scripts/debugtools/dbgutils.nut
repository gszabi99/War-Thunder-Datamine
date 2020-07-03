// warning disable: -file:forbidden-function

local dbgExportToFile = require("scripts/debugTools/dbgExportToFile.nut")
local shopSearchCore = require("scripts/shop/shopSearchCore.nut")
local dirtyWordsFilter = require("scripts/dirtyWords/dirtyWords.nut")
local { getWeaponInfoText, getWeaponNameText } = require("scripts/weaponry/weaponryVisual.nut")

::callstack <- dagor.debug_dump_stack

::reload <- function reload()
{
  return ::g_script_reloader.reload(::reload_main_script_module)
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
  local params = {
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
  local item = params.items[params.currentIndex]
  local blk = ::DataBlock()
  blk.setStr("what", "addItem")
  blk.setStr("item", item.id)
  blk.addInt("howmuch", params.count);
  local taskId = ::char_send_blk("dev_hack", blk)
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
  local rows = ::debriefing_rows
  local result = ::debriefing_result
  ::reload()

  local recountFunc = ::gather_debriefing_result
  local canRecount = "_stat_get_exp" in ::getroottable()
  if (!canRecount)
  {
    ::gather_debriefing_result = function() {}
    ::debriefing_rows = rows
    ::debriefing_result = result
  }

  gui_start_debriefingFull()

  if (!canRecount)
    ::gather_debriefing_result = recountFunc
}

::debug_debriefing_unlocks <- function debug_debriefing_unlocks(unlocksAmount = 5)
{
  ::gui_start_debriefingFull({ debugUnlocks = unlocksAmount })
}

::debug_get_every_day_login_award_userlog <- function debug_get_every_day_login_award_userlog(skip = 0, launchWindow = true)
{
  local total = ::get_user_logs_count()
  for (local i = total-1; i > 0; i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk.type == ::EULT_CHARD_AWARD && ::getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward")
    {
      if (skip > 0)
      {
        skip--
        continue
      }

      if (launchWindow)
        ::gui_start_show_login_award(blk)
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
      local res = []
      local wpCost = ::get_wpcost_blk()
      for (local i = 0; i < wpCost.blockCount(); i++) {
        local unit = ::getAircraftByName(wpCost.getBlock(i).getBlockName())
        if (unit?.isInShop)
          res.append(unit)
      }
      return res
    }()
    itemProcessFunc = function(unit) {
      local blk = ::DataBlock()
      foreach(weapon in unit.weapons)
        if (!::isWeaponAux(weapon))
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

::debug_export_unit_xray_parts_descriptions <- function debug_export_unit_xray_parts_descriptions()
{
  ::dmViewer.toggle(::DM_VIEWER_XRAY)
  dbgExportToFile.export({
    resultFilePath = "export/unitsXray.blk"
    itemsPerFrame = 10
    list = function() {
      local res = []
      local wpCost = ::get_wpcost_blk()
      for (local i = 0; i < wpCost.blockCount(); i++) {
        local unit = ::getAircraftByName(wpCost.getBlock(i).getBlockName())
        if (unit?.isInShop)
          res.append(unit)
      }
      return res
    }()
    itemProcessFunc = function(unit) {
      local blk = ::DataBlock()

      ::dmViewer.updateUnitInfo(unit.name)
      local partNames = []
      local damagePartsBlk = ::dmViewer.unitBlk?.DamageParts
      if (damagePartsBlk)
        for (local b = 0; b < damagePartsBlk.blockCount(); b++)
        {
          local partsBlk = damagePartsBlk.getBlock(b)
          for (local p = 0; p < partsBlk.blockCount(); p++)
            ::u.appendOnce(partsBlk.getBlock(p).getBlockName(), partNames)
        }
      partNames.sort()

      foreach (partName in partNames)
      {
        local params = { name = partName }
        local info = ::dmViewer.getPartTooltipInfo(::dmViewer.getPartNameId(params), params)
        if (info.desc != "")
          blk[partName] <- ::g_string.stripTags(info.title + "\n" + info.desc)
      }
      return { key = unit.name, value = blk }
    }
    onFinish = @() ::dmViewer.toggle(::DM_VIEWER_NONE)
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
  local missionBlk = ::get_meta_mission_info_by_name(missionName)
  if (!::u.isDataBlock(missionBlk))
    return dlog("Not found mission " + missionName)

  local filePath = missionBlk?.mis_file
  local fullBlk = filePath && ::DataBlock(filePath)
  if (!::u.isDataBlock(fullBlk))
    return dlog("Not found mission blk " + filePath)

  local briefing = fullBlk?.mission_settings.briefing
  if (!::u.isDataBlock(briefing) || !briefing.blockCount())
    return dlog("Mission does not have briefing")

  local briefingClone = ::DataBlock()
  if (slidesAmount <= 0)
    briefingClone.setFrom(briefing)
  else
  {
    local slidesLeft = slidesAmount
    local parts = briefing % "part"
    local partsClone = []
    for(local i = parts.len()-1; i >= 0; i--)
    {
      local part = parts[i]
      local partClone = ::DataBlock()
      local slides = part % "slide"
      if (slides.len() <= slidesLeft)
      {
        partClone.setFrom(part)
        slidesLeft -= slides.len()
      }
      else
        for(local j = slides.len()-slidesLeft; j < slides.len(); j++)
        {
          local slide = slides[j]
          local slideClone = ::DataBlock()
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
  local restoreData = {
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

    local fooTimerObj = "timer { id:t = 'debug_loading_timer'; timer_handler_func:t = 'onUpdate' }"
    handler.guiScene.appendWithBlk(handler.scene, fooTimerObj, null)
    local curTimerObj = handler.scene.findObject("debug_loading_timer")
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
  local units = shopSearchCore.findUnitsByLocName(unitLocName, true, needIncludeNotInShop)
  units.sort(function(a, b) { return a.name == b.name ? 0 : a.name < b.name ? -1 : 1 })

  local res = ::u.map(units, function(unit) {
    local locName = ::getUnitName(unit)
    local army = unit.unitType.getArmyLocName()
    local country = ::loc(::getUnitCountry(unit))
    local rank = ::get_roman_numeral(::getUnitRank(unit))
    local prem = (::isUnitSpecial(unit) || ::isUnitGift(unit)) ? ::loc("shop/premiumVehicle/short") : ""
    local hidden = !unit.isInShop ? ::loc("controls/NA") : unit.isVisibleInShop() ? "" : ::loc("worldWar/hided_logs")
    return unit.name + "; \"" + locName + "\" (" + ::g_string.implode([ army, country, rank, prem, hidden ], ", ") + ")"
  })

  foreach (line in res)
    dlog(line)
  return res.len()
}

::debug_show_unit <- function debug_show_unit(unitId)
{
  local unit = ::getAircraftByName(unitId)
  if (!unit)
    return "Not found"
  ::show_aircraft = unit
  ::gui_start_decals()
  return "Done"
}

::debug_show_weapon <- function debug_show_weapon(weaponName)
{
  weaponName = ::get_weapon_name_by_blk_path(weaponName)
  foreach (u in ::all_units)
  {
    if (!u.isInShop)
      continue
    local unitBlk = ::get_full_unit_blk(u.name)
    if (!unitBlk?.weapon_presets)
      continue

    foreach (presetMetaBlk in (unitBlk.weapon_presets % "preset"))
    {
      local presetBlk = ::DataBlock(presetMetaBlk?.blk ?? "")
      if (!presetBlk)
        continue
      foreach (weaponMetaBlk in (presetBlk % "Weapon"))
        if (weaponName == ::get_weapon_name_by_blk_path(weaponMetaBlk?.blk ?? ""))
        {
          ::open_weapons_for_unit(u)
          return $"{u.name} / {weaponMetaBlk.blk}"
        }
    }
  }
  return null
}

::debug_change_language <- function debug_change_language(isNext = true)
{
  local list = ::g_language.getGameLocalizationInfo()
  local curLang = ::get_current_language()
  local curIdx = list.findindex( @(l) l.id == curLang ) ?? 0
  local newIdx = curIdx + (isNext ? 1 : -1 + list.len())
  local newLang = list[newIdx % list.len()]
  ::g_language.setGameLocalization(newLang.id, true, false)
  dlog("Set language: " + newLang.id)
}

::debug_change_resolution <- function debug_change_resolution(shouldIncrease = true)
{
  local curResolution = ::getSystemConfigOption("video/resolution")
  local list = ::sysopt.mShared.getVideoModes(curResolution, false)
  local curIdx = list.indexof(curResolution) || 0
  local newIdx = ::clamp(curIdx + (shouldIncrease ? 1 : -1), 0, list.len() - 1)
  local newResolution = list[newIdx]
  local done = @() dlog("Set resolution: " + newResolution +
    " (" + screen_width() + "x" + screen_height() + ")")
  if (newResolution == curResolution)
    return done()
  ::setSystemConfigOption("video/resolution", newResolution)
  ::on_renderer_settings_change()
  ::perform_delayed(function() {
    ::handlersManager.getActiveBaseHandler().fullReloadScene()
    ::call_darg("updateExtWatched", { resolution = newResolution })
    done()
  })
}

::debug_multiply_color <- function debug_multiply_color(colorStr, multiplier)
{
  local res = ::g_dagui_utils.multiplyDaguiColorStr(colorStr, multiplier)
  ::copy_to_clipboard(res)
  return res
}

::debug_get_last_userlogs <- function debug_get_last_userlogs(num = 1)
{
  local total = ::get_user_logs_count()
  local res = []
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
  ::require("scripts/seen/seenList.nut").clearAllSeenData()
}

::debug_check_dirty_words <- function debug_check_dirty_words(path = null)
{
  local blk = ::DataBlock()
  blk.load(path || "debugDirtyWords.blk")
  local failed = 0
  for (local i = 0; i < blk.paramCount(); i++)
  {
    local text = blk.getParamValue(i)
    local filteredText = dirtyWordsFilter.checkPhrase(text)
    if (text == filteredText)
    {
      ::dagor.debug("DIRTYWORDS: PASSED " + text)
      failed++
    }
  }
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
      local remain = ::_debug_unit_rent[id].expire - ::get_charserver_time_sec()
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
  debug_wnd("gui/debugTools/dbgTipsList.tpl",
    {tipsList = ::g_tips.getAllTips().map(@(value) { value = value })})
}

::debug_get_skyquake_path <- function debug_get_skyquake_path() {
  local dir = ::get_exe_dir()
  local idx = dir.indexof("/skyquake/")
  return idx != null ? dir.slice(0, idx + 9) : ""
}

::debug_load_anim_bg <- require("scripts/loading/animBg.nut").debugLoad