import "%scripts/unlocks/unlockGroupWnd.nut" as showUnlocksGroupWnd
from "%scripts/unit/unitsData.nut" import getAllUnits
import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/unlocks/showUnlockHandler.nut" import ShowUnlockHandler
from "%scripts/langUtils/language.nut" import getGameLocalizationInfo
from "%scripts/langUtils/langJobs.nut" import registerLangJob, startLangJob
from "%scripts/unlocks/unlocksState.nut" import getFullUnlockDesc, getUnlockNameText, buildConditionsConfig
from "%scripts/unlocks/unlocksViewModule.nut" import getUnlockCostText
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById, getAllUnlocks
from "%scripts/unlocks/unlocksModule.nut" import hasMultiStageLocId
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/unlocks/showUnlockWnd.nut" import guiStartUnlockWnd
from "%scripts/items/trophyRewardWnd.nut" import guiStartOpenTrophy
from "%scripts/userLog/userlogUtils.nut" import getUserLogsList
from "%scripts/unlocks/unlocks.nut" import buildLogUnlockData
from "string" import format
from "language" import getLocalLanguage
from "console" import register_command
from "%sqstd/json.nut" import saveJson
from "%globalScripts/unlockConsts.nut" import *
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath
from "%scripts/webRPC.nut" import webRpcRegister


let { multiStageLocIdConfig } = require("%scripts/unlocks/unlocksModule.nut")

function debug_show_test_unlocks(chapter = "test", group = null) {
  if (!is_dev_version())
    return

  let awardsList = []
  foreach (_id, unlock in getAllUnlocks())
    if ((!chapter || unlock?.chapter == chapter) && (!group || unlock.group == group))
      awardsList.append(buildLogUnlockData({ id = unlock.id }))
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
      let data = buildLogUnlockData({ id = unlock.id })
      data.title = unlock.id
      awardsList.append(data)
    }
    else {
      let paramShift = unlock?.stage.param ?? 0
      foreach (key, _stageId in multiStageLocIdConfig[unlock.id]) {
        let stage = is_numeric(key) ? key : 99
        let data = buildLogUnlockData({ id = unlock.id, stage = stage - paramShift })
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
    let cfg = buildConditionsConfig(unlock)
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
    curVal = showValue ? null : "{value}" 
  }

  foreach (id, unlock in getAllUnlocks()) {
    let cfg = buildConditionsConfig(unlock)
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

const LANG_JOB_ID = "debugTools.dbgUnlocks"

function gen_all_unlocks_desc_to_blk_lang(lang, data, onDone) {
  let { path, showCost, showValue, status } = data
  try {
    gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)
    status[lang] <- {
      success=true
    }
  } catch (e) {
    logerr($"Failed to get unlocks desc blk for '{lang}' lang")
    status[lang] <- {
      success=false
    }
  }
  onDone()
}

registerLangJob(LANG_JOB_ID, gen_all_unlocks_desc_to_blk_lang,
  @(data) saveJson($"{data.path}/status.json", data.status))

function _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo) {
  startLangJob(LANG_JOB_ID, langsInfo.map(@(lang) lang.id), { path, showCost, showValue, status = {} })
}

function exportUnlockInfo(params) {
  let info = getGameLocalizationInfo().filter(@(value) params.langs.indexof(value.id) != null)
  _gen_all_unlocks_desc_to_blk(params.path, false, false, info)
  return "ok"
}

webRpcRegister("exportUnlockInfo", exportUnlockInfo)

function gen_all_unlocks_desc_to_blk(path = "unlockDesc", showCost = false, showValue = false, all_langs = true) {
  if (!all_langs)
    return gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  _gen_all_unlocks_desc_to_blk(path, showCost, showValue, getGameLocalizationInfo())
}

function debug_show_unlock_popup(unlockId) {
  guiStartUnlockWnd(
    buildLogUnlockData(
      buildConditionsConfig(
        getUnlockById(unlockId)
      )
    )
  )
}

function debug_show_debriefing_trophy(trophyItemId) {
  let filteredLogs = getUserLogsList({
    show = [EULT_OPEN_TROPHY]
    disableVisible = true
    needStackItems = false
    checkFunc = @(userlog) trophyItemId == userlog.body.id
  })

  guiStartOpenTrophy({ [trophyItemId] = filteredLogs })
}

function debug_new_unit_unlock(needTutorial = false, unitName = null) {
  local unit = getAircraftByName(unitName)
  if (!unit)
    unit = u.search(getAllUnits(), @(un) un.isBought())

  loadHandler(ShowUnlockHandler,
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
