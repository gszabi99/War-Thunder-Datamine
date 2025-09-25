
from "%scripts/dagui_natives.nut" import copy_to_clipboard
from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { DBGLEVEL } = require("dagor.system")
if (DBGLEVEL <= 0)
  return

let { HudBattleLog, setBattleLog } = require("%scripts/hud/hudBattleLog.nut")
let g_path = require("%sqstd/path.nut")
let dagor_fs = require("dagor.fs")
let { getDebriefingResult, setDebriefingResult, recountDebriefingResult
} = require("%scripts/debriefing/debriefingFull.nut")
let { guiStartDebriefingFull } = require("%scripts/debriefing/debriefingModal.nut")
let { setSquadPlayersInfo, initListLabelsSquad } = require("%scripts/statistics/squadIcon.nut")
let { register_command } = require("console")
let { debug_get_skyquake_path } = require("%scripts/debugTools/dbgUtils.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")
let { loadJson, saveJson } = require("%sqstd/json.nut")

function debug_dump_debriefing_save(fileName) {
  let debriefingResult = getDebriefingResult()
  if (!debriefingResult)
    return "IGNORED: No debriefingResult, or dump is loaded."
  let res = clone debriefingResult
  res.battleLog <- HudBattleLog.battleLog
  saveJson(fileName, res)

  return $"Debriefing result saved to {fileName}"
}

let debriefingDataWithIntegerKey = ["playersInfo", "overrideCountryIconByTeam"]

function debug_dump_debriefing_load(fileName, onUnloadFunc = null) {
  let data = loadJson(fileName)
  if (data == null)
    return console_print($"Can not load file {fileName}")

  foreach (id in debriefingDataWithIntegerKey) {
    if (id not in data)
      continue
    let res = {}
    foreach (key, value in data[id])
      res[key.tointeger()] <- value
    data[id] = res
  }
  setBattleLog(data?.battleLog)
  initListLabelsSquad()
  setSquadPlayersInfo(data?.playersInfo)
  setDebriefingResult(data)
  recountDebriefingResult()
  guiStartDebriefingFull({ callbackOnDebriefingClose = onUnloadFunc })
  checkNonApprovedResearches(true)
  broadcastEvent("SessionDestroyed")
  return console_print($"Debriefing result loaded from {fileName}")
}

function debug_dump_debriefing_batch_load() {
  let skyquakePath = debug_get_skyquake_path()
  let filesList = dagor_fs.scan_folder({ root = $"{skyquakePath}/gameOnline",
    files_suffix = "*.json", recursive = false, vromfs = false, realfs = true
  }).filter(@(v) v.contains("debug_dump_debriefing") && !v.contains("_SKIP.json"))
    .map(@(v) g_path.fileName(v)).sort().reverse()
  let total = filesList.len()
  function loadNext() {
    let count = filesList.len()
    if (!count)
      return
    let filename = filesList.pop()
    console_print($"[{total - count + 1}/{total}] {filename}")
    copy_to_clipboard(filename)
    debug_dump_debriefing_load(filename, loadNext)
  }
  loadNext()
}

let defDebriefingFile = "debug_dump_debriefing.json"
register_command(@() debug_dump_debriefing_save(defDebriefingFile), "debug.dump.debriefing_save")
register_command(debug_dump_debriefing_save, "debug.dump.debriefing_save_to_file")
register_command(@() debug_dump_debriefing_load(defDebriefingFile), "debug.dump.debriefing_load")
register_command(@(file) debug_dump_debriefing_load(file), "debug.dump.debriefing_load_from_file")
register_command(debug_dump_debriefing_batch_load, "debug.dump.debriefing_batch_load")
