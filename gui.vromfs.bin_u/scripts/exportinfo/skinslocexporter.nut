from "%scripts/dagui_library.nut" import *
from "dagor.fs" import mkpath

let { defer } = require("dagor.workcycle")
let { setGameLocalization,getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")

let DataBlock  = require("DataBlock")

let { getLocalLanguage } = require("language")

let { decoratorTypes } = require("%scripts/customization/types.nut")

let { saveJson } = require("%sqstd/json.nut")
let { web_rpc } = require("%scripts/webRPC.nut")

let { getCachedDecoratorsListByType } = require("%scripts/customization/decorCache.nut")

function genAllSkinLocksToBlkCurLang(path) {
  let fullPath = $"{path}/skins{getLocalLanguage()}.blk"
  log($"GP: gen all loc skins to {fullPath}")

  let res = DataBlock()
  let skins = getCachedDecoratorsListByType(decoratorTypes.SKINS)

  foreach (id, skin in skins) {
    if (!skin || !skin.isVisible())
      continue

    let blk = DataBlock()
    blk.title = skin.getLocalizedName()
    blk.desc = skin.getDesc()
    res[id] = blk
  }

  mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

function makeLoc(path, langsInfo, curLang, status = {}) {
  let makeLocImp = callee()
  let lang = langsInfo.pop()
  setGameLocalization(lang.id, false, false)
  try {
    genAllSkinLocksToBlkCurLang(path)
    status[lang.id] <- {
      success=true
    }
  } catch (e) {
    logerr($"Failed to get skins list blk for '{lang}' lang")
    status[lang.id] <- {
      success=false
    }
  }

  if (!langsInfo.len()) {
    saveJson($"{path}/status.json", status)
    return setGameLocalization(curLang, false, false)
  }

  defer(@() makeLocImp(path, langsInfo, curLang, status))
}

function exportSkinsInfo(params) {
  let info = getGameLocalizationInfo().filter(@(value) params.langs.contains(value.id))
  makeLoc(params.path, info, getLocalLanguage())
  return "ok"
}

web_rpc.register_handler("exportSkinsInfo", exportSkinsInfo)