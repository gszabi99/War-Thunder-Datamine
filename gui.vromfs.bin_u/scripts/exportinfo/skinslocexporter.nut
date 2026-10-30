import "DataBlock" as DataBlock
from "%scripts/langUtils/language.nut" import getGameLocalizationInfo
from "%scripts/langUtils/langJobs.nut" import registerLangJob, startLangJob
from "%scripts/customization/decoratorGetters.nut" import getVisibleDecoratorsByType
from "language" import getLocalLanguage
from "%sqstd/json.nut" import saveJson
from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath
from "%scripts/webRPC.nut" import webRpcRegister

let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")

function genAllSkinLocksToBlkCurLang(path) {
  let fullPath = $"{path}/skins{getLocalLanguage()}.blk"
  log($"GP: gen all loc skins to {fullPath}")

  let res = DataBlock()
  foreach (skin in getVisibleDecoratorsByType(decoratorTypes.SKINS)) {
    let blk = DataBlock()
    blk.title = skin.getLocalizedName()
    blk.desc = skin.getDesc()
    res[skin.id] = blk
  }

  mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

const LANG_JOB_ID = "exportInfo.skinsLocExporter"

function makeLoc(lang, data, onDone) {
  let { path, status } = data
  try {
    genAllSkinLocksToBlkCurLang(path)
    status[lang] <- {
      success=true
    }
  } catch (e) {
    logerr($"Failed to get skins list blk for '{lang}' lang")
    status[lang] <- {
      success=false
    }
  }
  onDone()
}

registerLangJob(LANG_JOB_ID, makeLoc, @(data) saveJson($"{data.path}/status.json", data.status))

function exportSkinsInfo(params) {
  let langs = getGameLocalizationInfo().filter(@(value) params.langs.contains(value.id)).map(@(lang) lang.id)
  startLangJob(LANG_JOB_ID, langs, { path = params.path, status = {} })
  return "ok"
}

webRpcRegister("exportSkinsInfo", exportSkinsInfo)