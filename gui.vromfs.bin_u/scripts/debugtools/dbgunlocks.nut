//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock  = require("DataBlock")
let { format } = require("string")
// warning disable: -file:forbidden-function
let { getFullUnlockDesc, getUnlockCostText,
  getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { register_command } = require("console")
let { getUnlockById, getAllUnlocks } = require("%scripts/unlocks/unlocksCache.nut")

let function debug_show_test_unlocks(chapter = "test", group = null) {
  if (!::is_dev_version)
    return

  let awardsList = []
  foreach (_id, unlock in getAllUnlocks())
    if ((!chapter || unlock?.chapter == chapter) && (!group || unlock.group == group))
      awardsList.append(::build_log_unlock_data({ id = unlock.id }))
  let titleText = "debug_show_test_unlocks (total: " + awardsList.len() + ")"
  showUnlocksGroupWnd(awardsList, titleText)
}

let function debug_show_all_streaks() {
  if (!::is_dev_version)
    return

  local total = 0
  let awardsList = []
  foreach (_id, unlock in getAllUnlocks()) {
    if (unlock.type != "streak" || unlock?.hidden)
      continue
    total++

    if (!::g_unlocks.isUnlockMultiStageLocId(unlock.id)) {
      let data = ::build_log_unlock_data({ id = unlock.id })
      data.title = unlock.id
      awardsList.append(data)
    }
    else {
      let paramShift = unlock?.stage.param ?? 0
      foreach (key, _stageId in ::g_unlocks.multiStageLocId[unlock.id]) {
        let stage = ::is_numeric(key) ? key : 99
        let data = ::build_log_unlock_data({ id = unlock.id, stage = stage - paramShift })
        data.title = unlock.id + " / " + stage
        awardsList.append(data)
      }
    }
  }

  let titleText = "debug_show_all_streaks (total: " + total + ")"
  showUnlocksGroupWnd(awardsList, titleText)
}

let function gen_all_unlocks_desc(showCost = false) {
  dlog("GP: gen all unlocks description")
  local res = ""
  foreach (_id, unlock in getAllUnlocks()) {
    let cfg = ::build_conditions_config(unlock)
    local desc = getFullUnlockDesc(cfg)
    if (showCost)
      desc = $"{desc}\n{getUnlockCostText(cfg)}"
    res += "\n" + unlock.id + ":" + (desc != "" ? "\n" : "") + desc
  }
  dlog("GP: res:")
  log(res)
  dlog("GP: done")
}

let function gen_all_unlocks_desc_to_blk_cur_lang(path = "unlockDesc", showCost = false, showValue = false) {
  let fullPath = format("%s/unlocks%s.blk", path, ::get_current_language())
  dlog("GP: gen all unlocks description to " + fullPath)

  let res = DataBlock()
  let params = {
    curVal = showValue ? null : "{value}" // warning disable: -forgot-subst
  }

  foreach (id, unlock in getAllUnlocks()) {
    let cfg = ::build_conditions_config(unlock)
    local desc = getFullUnlockDesc(cfg, params)
    if (showCost)
      desc = $"{desc}\n{getUnlockCostText(cfg)}"

    let blk = DataBlock()
    blk.name = getUnlockNameText(cfg.unlockType, id)
    blk.desc = desc
    res[id] = blk
  }
  ::dd_mkpath?(fullPath)
  res.saveToTextFile(fullPath)
}

let function _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang) {
  let self = callee()
  let lang = langsInfo.pop()
  ::g_language.setGameLocalization(lang.id, false, false)
  gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  if (!langsInfo.len())
    return ::g_language.setGameLocalization(curLang, false, false)

  //delayed to easy see progress, and avoid watchdog crash.
  let guiScene = ::get_main_gui_scene()
  guiScene.performDelayed(this, function() {
    self(path, showCost, showValue, langsInfo, curLang)
  })
}

let function exportUnlockInfo(params) {
  let info = ::g_language.getGameLocalizationInfo().filter(@(value) params.langs.indexof(value.id) != null)
  _gen_all_unlocks_desc_to_blk(params.path, false, false, info, ::get_current_language())
  return "ok"
}

::web_rpc.register_handler("exportUnlockInfo", exportUnlockInfo)

let function gen_all_unlocks_desc_to_blk(path = "unlockDesc", showCost = false, showValue = false, all_langs = true) {
  if (!all_langs)
    return gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  let curLang = ::get_current_language()
  let info = ::g_language.getGameLocalizationInfo()
  _gen_all_unlocks_desc_to_blk(path, showCost, showValue, info, curLang)
}

let function debug_show_unlock_popup(unlockId) {
  ::gui_start_unlock_wnd(
    ::build_log_unlock_data(
      ::build_conditions_config(
        getUnlockById(unlockId)
      )
    )
  )
}

let function debug_show_debriefing_trophy(trophyItemId) {
  let filteredLogs = ::getUserLogsList({
    show = [EULT_OPEN_TROPHY]
    disableVisible = true
    checkFunc = @(userlog) trophyItemId == userlog.body.id
  })

  ::gui_start_open_trophy({ [trophyItemId] = filteredLogs })
}

let function debug_new_unit_unlock(needTutorial = false, unitName = null) {
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    unit = ::u.search(::all_units, @(u) u.isBought())

  ::gui_start_modal_wnd(::gui_handlers.ShowUnlockHandler,
    {
      config = {
         type = UNLOCKABLE_AIRCRAFT
         id = unit.name
         name = unit.name
      }
      needShowUnitTutorial = needTutorial
    })
}

register_command(debug_show_test_unlocks, "debug.unlocks.show_test_unlocks")
register_command(debug_show_all_streaks, "debug.unlocks.show_all_streaks")
register_command(@() gen_all_unlocks_desc(), "debug.unlocks.gen_all_unlocks_desc")
register_command(@() gen_all_unlocks_desc(true), "debug.unlocks.gen_all_unlocks_desc_with_cost")
register_command(gen_all_unlocks_desc_to_blk, "debug.unlocks.gen_all_unlocks_desc_to_blk")
register_command(debug_show_unlock_popup, "debug.unlocks.debug_show_unlock_popup")
register_command(debug_show_debriefing_trophy, "debug.unlocks.debug_show_debriefing_trophy")
register_command(debug_new_unit_unlock, "debug.unlocks.debug_new_unit_unlock")
