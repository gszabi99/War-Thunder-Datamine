let { format } = require("string")
// warning disable: -file:forbidden-function
let { openBattlePassWnd } = require("%scripts/battlePass/battlePassWnd.nut")
let { getFullUnlockDesc } = require("%scripts/unlocks/unlocksViewModule.nut")

::debug_show_test_unlocks <- function debug_show_test_unlocks(chapter = "test", group = null)
{
  if (!::is_dev_version)
    return

  let awardsList = []
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
  let awardsList = []
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    if (unlock.type != "streak" || unlock?.hidden)
      continue
    total++

    if (!::g_unlocks.isUnlockMultiStageLocId(unlock.id))
    {
      let data = ::build_log_unlock_data({ id = unlock.id })
      data.title = unlock.id
      awardsList.append(data)
    }
    else
    {
      let paramShift = unlock?.stage.param ?? 0
      foreach(key, stageId in ::g_unlocks.multiStageLocId[unlock.id])
      {
        let stage = ::is_numeric(key) ? key : 99
        let data = ::build_log_unlock_data({ id = unlock.id, stage = stage - paramShift })
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
  let params = {showCost = showCost}
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    let cfg = ::build_conditions_config(unlock)
    let desc = getFullUnlockDesc(cfg, params)
    res += "\n" + unlock.id + ":" + (desc != ""? "\n" : "") + desc
  }
  dlog("GP: res:")
  ::dagor.debug(res)
  dlog("GP: done")
}

::exportUnlockInfo <- function exportUnlockInfo(params)
{
  let info = ::g_language.getGameLocalizationInfo().filter(@(value) params.langs.indexof(value.id) != null)
  _gen_all_unlocks_desc_to_blk(params.path, false, false, info, ::get_current_language())
  return "ok"
}

web_rpc.register_handler("exportUnlockInfo", exportUnlockInfo)

::gen_all_unlocks_desc_to_blk <- function gen_all_unlocks_desc_to_blk(path = "unlockDesc", showCost = false, showValue = false, all_langs = true)
{
  if (!all_langs)
    return gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  let curLang = ::get_current_language()
  let info = ::g_language.getGameLocalizationInfo()
  _gen_all_unlocks_desc_to_blk(path, showCost, showValue, info, curLang)
}

::_gen_all_unlocks_desc_to_blk <- function _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang)
{
  let lang = langsInfo.pop()
  ::g_language.setGameLocalization(lang.id, false, false)
  gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  if (!langsInfo.len())
    return ::g_language.setGameLocalization(curLang, false, false)

  //delayed to easy see progress, and avoid watchdog crash.
  let guiScene = ::get_main_gui_scene()
  guiScene.performDelayed(this, (@(path, showCost, showValue, langsInfo, curLang) function () {
    _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang)
  })(path, showCost, showValue, langsInfo, curLang))
}

::gen_all_unlocks_desc_to_blk_cur_lang <- function gen_all_unlocks_desc_to_blk_cur_lang(path = "unlockDesc", showCost = false, showValue = false)
{
  let fullPath = format("%s/unlocks%s.blk", path, ::get_current_language())
  dlog("GP: gen all unlocks description to " + fullPath)

  let res = ::DataBlock()
  let params = {
                   showCost = showCost,
                   curVal = showValue ? null : "{value}" // warning disable: -forgot-subst
                 }

  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    let cfg = ::build_conditions_config(unlock)
    let desc = getFullUnlockDesc(cfg, params)

    let blk = ::DataBlock()
    blk.name = ::get_unlock_name_text(cfg.unlockType, id)
    blk.desc = desc
    res[id] = blk
  }
  ::dd_mkpath?(fullPath)
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
  let filteredLogs = ::getUserLogsList({
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

::open_battle_pass_wnd <- @() openBattlePassWnd()
