import "DataBlock" as DataBlock
from "%scripts/unlocks/unlocksCache.nut" import getAllUnlocks
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible
from "%scripts/langUtils/language.nut" import getGameLocalizationInfo
from "%scripts/langUtils/langJobs.nut" import registerLangJob, startLangJob
from "language" import getLocalLanguage
from "%sqstd/json.nut" import saveJson
from "console" import register_command
from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath
from "%scripts/webRPC.nut" import webRpcRegister

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

const LANG_JOB_ID = "exportInfo.historyPagesLocExporter"

function makeLoc(lang, data, onDone) {
  let { path, status } = data
  try {
    genHPLocksToBlkCurLang(path)
    status[lang] <- {
      success=true
    }
  } catch (e) {
    logerr($"Failed to get history pages localization blk for '{lang}' lang")
    status[lang] <- {
      success=false
    }
  }
  onDone()
}

registerLangJob(LANG_JOB_ID, makeLoc, function(data) {
  saveJson($"{data.path}/{data.exportFileName}", data.status)
  log($"GP: history pages localization parsing finished")
})

function exportHPLocInfo(params) {
  let langs = getGameLocalizationInfo().filter(@(value) params.langs.contains(value.id)).map(@(lang) lang.id)
  return startLangJob(LANG_JOB_ID, langs, { path = params.path, exportFileName = params.fileName, status = {} })
    ? "ok"
    : "error: another language job or an export runs"
}

webRpcRegister("exportHPLocInfo", exportHPLocInfo)
register_command(@(filePath) exportHPLocInfo({path = filePath, langs = ["English", "Russian", "Japanese"]}), "debug.print_hp_loc_info")