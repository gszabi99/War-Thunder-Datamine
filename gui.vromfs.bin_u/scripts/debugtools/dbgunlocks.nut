// warning disable: -file:forbidden-function
//


::debug_show_test_unlocks <- function debug_show_test_unlocks(chapter = "test", group = null)
{
  if (!::is_dev_version)
    return

  local awardsList = []
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
    if((!chapter || unlock.chapter == chapter) && (!group || unlock.group == group))
      awardsList.append(::build_log_unlock_data({ id = unlock.id }))
  ::showUnlocksGroupWnd([{
    unlocksList = awardsList
    titleText = "debug_show_test_unlocks (total: " + awardsList.len() + ")"
  }])
}

::debug_show_all_streaks <- function debug_show_all_streaks()
{
  if (!::is_dev_version)
    return

  local total = 0
  local awardsList = []
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    if (unlock.type != "streak" || unlock.hidden)
      continue
    total++

    if (!::g_unlocks.isUnlockMultiStageLocId(unlock.id))
    {
      local data = ::build_log_unlock_data({ id = unlock.id })
      data.title = unlock.id
      awardsList.append(data)
    }
    else
    {
      local paramShift = unlock?.stage.param ?? 0
      foreach(key, stageId in ::g_unlocks.multiStageLocId[unlock.id])
      {
        local stage = ::is_numeric(key) ? key : 99
        local data = ::build_log_unlock_data({ id = unlock.id, stage = stage - paramShift })
        data.title = unlock.id + " / " + stage
        awardsList.append(data)
      }
    }
  }

  ::showUnlocksGroupWnd([{
    unlocksList = awardsList,
    titleText = "debug_show_all_streaks (total: " + total + ")"
  }])
}

::gen_all_unlocks_desc <- function gen_all_unlocks_desc(showCost = false)
{
  dlog("GP: gen all unlocks description")
  local res = ""
  local params = {showCost = showCost}
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    local data = ::build_conditions_config(unlock)
    local desc = ::getUnlockDescription(data, params)
    res += "\n" + unlock.id + ":" + (desc != ""? "\n" : "") + desc
  }
  dlog("GP: res:")
  dagor.debug(res)
  dlog("GP: done")
}

::exportUnlockInfo <- function exportUnlockInfo(params)
{
  local info = ::g_language.getGameLocalizationInfo().filter(@(value) params.langs.indexof(value.id) != null)
  _gen_all_unlocks_desc_to_blk(params.path, false, false, info, ::get_current_language())
  return "ok"
}

web_rpc.register_handler("exportUnlockInfo", exportUnlockInfo)

::gen_all_unlocks_desc_to_blk <- function gen_all_unlocks_desc_to_blk(path = "unlockDesc", showCost = false, showValue = false, all_langs = true)
{
  if (!all_langs)
    return gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  local curLang = ::get_current_language()
  local info = ::g_language.getGameLocalizationInfo()
  _gen_all_unlocks_desc_to_blk(path, showCost, showValue, info, curLang)
}

::_gen_all_unlocks_desc_to_blk <- function _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang)
{
  local lang = langsInfo.pop()
  ::g_language.setGameLocalization(lang.id, false, false)
  gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  if (!langsInfo.len())
    return ::g_language.setGameLocalization(curLang, false, false)

  //delayed to easy see progress, and avoid watchdog crash.
  local guiScene = ::get_main_gui_scene()
  guiScene.performDelayed(this, (@(path, showCost, showValue, langsInfo, curLang) function () {
    _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang)
  })(path, showCost, showValue, langsInfo, curLang))
}

::gen_all_unlocks_desc_to_blk_cur_lang <- function gen_all_unlocks_desc_to_blk_cur_lang(path = "unlockDesc", showCost = false, showValue = false)
{
  local fullPath = ::format("%s/unlocks%s.blk", path, ::get_current_language())
  dlog("GP: gen all unlocks description to " + fullPath)

  local res = ::DataBlock()
  local params = {
                   showCost = showCost,
                   curVal = showValue ? null : "{value}", // warning disable: -forgot-subst
                   maxVal = showValue ? null : "{maxValue}" // warning disable: -forgot-subst
                 }

  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    local data = ::build_conditions_config(unlock)
    local desc = ::getUnlockDescription(data, params)

    local blk = ::DataBlock()
    blk.name = ::get_unlock_name_text(data.unlockType, id)
    blk.desc = desc
    res[id] = blk
  }
  ::dd_mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

::debug_show_unlock_popup <- function debug_show_unlock_popup(unlockId)
{
  ::gui_start_unlock_wnd(
    ::build_log_unlock_data(
      ::build_conditions_config(
        ::g_unlocks.getUnlockById(unlockId)
      )
    )
  )
}

::debug_show_debriefing_trophy <- function debug_show_debriefing_trophy(trophyItemId) {
  local filteredLogs = ::getUserLogsList({
    show = [::EULT_OPEN_TROPHY]
    disableVisible = true
    checkFunc = @(userlog) trophyItemId == userlog.body.id
  })

  ::gui_start_open_trophy({ [trophyItemId] = filteredLogs })
}

::debug_new_unit_unlock <- function debug_new_unit_unlock(needTutorial = false, unitName = null)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    unit = ::u.search(::all_units, @(u) u.isBought())

  ::gui_start_modal_wnd(::gui_handlers.ShowUnlockHandler,
    {
      config = {
         type = ::UNLOCKABLE_AIRCRAFT
         id = unit.name
         name = unit.name
      }
      needShowUnitTutorial = needTutorial
    })
}
//


