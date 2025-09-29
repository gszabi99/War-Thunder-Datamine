from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath

let { getAllUnlocks } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { defer } = require("dagor.workcycle")
let { setGameLocalization,getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")

let DataBlock  = require("DataBlock")

let { getLocalLanguage } = require("language")

let { saveJson } = require("%sqstd/json.nut")
let { web_rpc } = require("%scripts/webRPC.nut")

let { register_command } = require("console")

function genHPLocksToBlkCurLang(path) {
  let fullPath = $"{path}/history_pages{getLocalLanguage()}.blk"
  log($"GP: gen history pages localization to {fullPath}")

  let res = DataBlock()
  let groups = []

  let unlocks = getAllUnlocks()
  foreach (unlockBlk in unlocks) {
    if (unlockBlk?.chapter != "history_pages" || !isUnlockVisible(unlockBlk) || unlockBlk?.group == null)
      continue
    let group = unlockBlk.group
    if (groups.contains(group))
     continue

    groups.append(group)
    res[group] = loc($"unlocks/group/{group}")
  }

  mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

function makeLoc(path, langsInfo, curLang, status = {}) {
  let makeLocImp = callee()
  let lang = langsInfo.pop()
  setGameLocalization(lang.id, false, false)
  if ("locInfo" not in status)
    status.locInfo <- {}

  try {
    genHPLocksToBlkCurLang(path)
    status.locInfo[lang.id] <- {
      success=true
    }
  } catch (e) {
    logerr($"Failed to get history pages localization blk for '{lang}' lang")
    status.locInfo[lang.id] <- {
      success=false
    }
  }

  if (!langsInfo.len()) {
    saveJson($"{path}/status.json", status)
    log($"GP: history pages localization parsing finished")
    return setGameLocalization(curLang, false, false)
  }

  defer(@() makeLocImp(path, langsInfo, curLang, status))
}

function exportHPLocInfo(params) {
  let info = getGameLocalizationInfo().filter(@(value) params.langs.contains(value.id))
  makeLoc(params.path, info, getLocalLanguage())
  return "ok"
}

web_rpc.register_handler("exportHPLocInfo", exportHPLocInfo)
register_command(@(filePath) exportHPLocInfo({path = filePath, langs = ["English", "Russian", "Japanese"]}), "debug.print_hp_loc_info")