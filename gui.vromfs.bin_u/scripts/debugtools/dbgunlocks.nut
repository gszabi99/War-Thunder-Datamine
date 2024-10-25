//-file:plus-string
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { setGameLocalization,getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")

let DataBlock  = require("DataBlock")
let { format } = require("string")
// warning disable: -file:forbidden-function
let { getLocalLanguage } = require("language")
let { getFullUnlockDesc, getUnlockCostText,
  getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { register_command } = require("console")
let { getUnlockById, getAllUnlocks } = require("%scripts/unlocks/unlocksCache.nut")
let { multiStageLocIdConfig, hasMultiStageLocId } = require("%scripts/unlocks/unlocksModule.nut")
let { saveJson } = require("%sqstd/json.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { guiStartUnlockWnd } = require("%scripts/unlocks/showUnlock.nut")
let { guiStartOpenTrophy } = require("%scripts/items/trophyRewardWnd.nut")

function debug_show_test_unlocks(chapter = "test", group = null) {
  if (!is_dev_version())
    return

  let awardsList = []
  foreach (_id, unlock in getAllUnlocks())
    if ((!chapter || unlock?.chapter == chapter) && (!group || unlock.group == group))
      awardsList.append(::build_log_unlock_data({ id = unlock.id }))
  let titleText = "".concat("debug_show_test_unlocks (total: ", awardsList.len(), ")")
  showUnlocksGroupWnd(awardsList, titleText)
}

function debug_show_all_streaks() {
  if (!is_dev_version())
    return

  local total = 0
  let awardsList = []
  foreach (_id, unlock in getAllUnlocks()) {
    if (unlock.type != "streak" || unlock?.hidden)
      continue
    total++

    if (!hasMultiStageLocId(unlock.id)) {
      let data = ::build_log_unlock_data({ id = unlock.id })
      data.title = unlock.id
      awardsList.append(data)
    }
    else {
      let paramShift = unlock?.stage.param ?? 0
      foreach (key, _stageId in multiStageLocIdConfig[unlock.id]) {
        let stage = is_numeric(key) ? key : 99
        let data = ::build_log_unlock_data({ id = unlock.id, stage = stage - paramShift })
        data.title = $"{unlock.id} / {stage}"
        awardsList.append(data)
      }
    }
  }

  let titleText = "".concat("debug_show_all_streaks (total: ", total, ")")
  showUnlocksGroupWnd(awardsList, titleText)
}

function gen_all_unlocks_desc(showCost = false) {
  dlog("GP: gen all unlocks description")
  local res = ""
  foreach (_id, unlock in getAllUnlocks()) {
    let cfg = ::build_conditions_config(unlock)
    local desc = getFullUnlockDesc(cfg)
    if (showCost)
      desc = $"{desc}\n{getUnlockCostText(cfg)}"
    res = "".concat(res, "\n", unlock.id, ":", (desc != "" ? "\n" : ""), desc)
  }
  dlog("GP: res:")
  log(res)
  dlog("GP: done")
}

function gen_all_unlocks_desc_to_blk_cur_lang(path = "unlockDesc", showCost = false, showValue = false) {
  let fullPath = format("%s/unlocks%s.blk", path, getLocalLanguage())
  dlog($"GP: gen all unlocks description to {fullPath}")

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
  mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

function _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang, status = {}) {
  let self = callee()
  let lang = langsInfo.pop()
  setGameLocalization(lang.id, false, false)
  try {
    gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)
    status[lang.id] <- {
      success=true
    }
  } catch (e) {
    logerr($"Failed to get unlocks desc blk for '{lang}' lang")
    status[lang.id] <- {
      success=false
    }
  }

  if (!langsInfo.len()) {
    saveJson($"{path}/status.json", status)
    return setGameLocalization(curLang, false, false)
  }

  //delayed to easy see progress, and avoid watchdog crash.
  let guiScene = get_main_gui_scene()
  guiScene.performDelayed(this, function() {
    self(path, showCost, showValue, langsInfo, curLang, status)
  })
}

function exportUnlockInfo(params) {
  let info = getGameLocalizationInfo().filter(@(value) params.langs.indexof(value.id) != null)
  _gen_all_unlocks_desc_to_blk(params.path, false, false, info, getLocalLanguage())
  return "ok"
}

web_rpc.register_handler("exportUnlockInfo", exportUnlockInfo)

function gen_all_unlocks_desc_to_blk(path = "unlockDesc", showCost = false, showValue = false, all_langs = true) {
  if (!all_langs)
    return gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  let curLang = getLocalLanguage()
  let info = getGameLocalizationInfo()
  _gen_all_unlocks_desc_to_blk(path, showCost, showValue, info, curLang)
}

function debug_show_unlock_popup(unlockId) {
  guiStartUnlockWnd(
    ::build_log_unlock_data(
      ::build_conditions_config(
        getUnlockById(unlockId)
      )
    )
  )
}

function debug_show_debriefing_trophy(trophyItemId) {
  let filteredLogs = ::getUserLogsList({
    show = [EULT_OPEN_TROPHY]
    disableVisible = true
    checkFunc = @(userlog) trophyItemId == userlog.body.id
  })

  guiStartOpenTrophy({ [trophyItemId] = filteredLogs })
}

function debug_new_unit_unlock(needTutorial = false, unitName = null) {
  local unit = getAircraftByName(unitName)
  if (!unit)
    unit = u.search(getAllUnits(), @(un) un.isBought())

  loadHandler(gui_handlers.ShowUnlockHandler,
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
