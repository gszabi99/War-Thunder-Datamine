from "dagor.workcycle" import defer
from "%sqstd/json.nut" import saveJson
from "dagor.fs" import mkpath
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_library.nut" import *
from "types" import Array

let { setGameLocalization, getGameLocalizationInfo } = require("%scripts/langUtils/language.nut")

const TARGET_WEAPONS_LOC = "weaponsLoc"

class ExporterStatus {
  static DETAILS_FIELD = "details"
  static SUCCESS_FIELD = "success"

  filename = ""
  status = null

  constructor(filename_) {
    this.filename = filename_
    this.status = {}
  }

  function setTargetField(target, field, value) {
    if (!(target in this.status))
      this.status[target] <- {}
    this.status[target][field] <- value
  }

  function setTargetDetails(target, details) {
    this.setTargetField(target, this.DETAILS_FIELD, details)
  }

  function finishTarget(target, isSuccess) {
    this.setTargetField(target, this.SUCCESS_FIELD, isSuccess)
  }

  function forceFlushToFile() {
    if (this.filename == "")
      return

    mkpath(this.filename)
    saveJson(this.filename, this.status)
  }
}

function makePath(path, fileName) {
  return path == "" ? fileName : $"{path}/{fileName}"
}

function tryLoc(key) {
  if (key == null || key == "")
    return ""
  return doesLocTextExist(key) ? loc(key) : ""
}

function pickStoredLocIds(data) {
  return {
    nameLocId = data?.nameLocId ?? ""
    shortLocId = data?.nameShortLocId ?? ""
    descLocId = data?.descLocId ?? ""
  }
}

function collectLocSpec(exportDb) {
  let res = {
    bullets = {}
    weapons = { barrels = {}, munitions = {} }
  }
  if (exportDb == null)
    return res

  foreach (id, data in (exportDb?.bullets ?? {}))
    res.bullets[id] <- pickStoredLocIds(data)

  let weapons = exportDb?.weapons ?? {}
  foreach (id, data in (weapons?.barrels ?? {}))
    res.weapons.barrels[id] <- pickStoredLocIds(data)
  foreach (id, data in (weapons?.munitions ?? {}))
    res.weapons.munitions[id] <- pickStoredLocIds(data)

  return res
}

function makeLangEntry(locIds) {
  let entry = {}

  let name = tryLoc(locIds.nameLocId)
  if (name != "") {
    entry.name <- name
    entry.nameLocKey <- locIds.nameLocId
  }

  let nameShort = tryLoc(locIds.shortLocId)
  if (nameShort != "") {
    entry.nameShort <- nameShort
    entry.nameShortLocKey <- locIds.shortLocId
  }

  let desc = tryLoc(locIds.descLocId)
  if (desc != "") {
    entry.desc <- desc
    entry.descLocKey <- locIds.descLocId
  }

  return entry
}

function buildLocTableForCurLang(spec) {
  let res = {
    bullets = {}
    weapons = { barrels = {}, munitions = {} }
  }

  foreach (id, locIds in spec.bullets) {
    let entry = makeLangEntry(locIds)
    if (entry.len() > 0)
      res.bullets[id] <- entry
  }
  foreach (id, locIds in spec.weapons.barrels) {
    let entry = makeLangEntry(locIds)
    if (entry.len() > 0)
      res.weapons.barrels[id] <- entry
  }
  foreach (id, locIds in spec.weapons.munitions) {
    let entry = makeLangEntry(locIds)
    if (entry.len() > 0)
      res.weapons.munitions[id] <- entry
  }

  return res
}

function makeLocOutPath(path, fileName, langId) {
  let dot = fileName.indexof(".")
  let stem = dot == null ? fileName : fileName.slice(0, dot)
  let ext = dot == null ? "json" : fileName.slice(dot + 1)
  return makePath(path, $"{stem}_{langId}.{ext}")
}

function resolveLangsInfo(requestedLangs) {
  if (requestedLangs == null || !(requestedLangs instanceof Array) || requestedLangs.len() == 0)
    return []
  return getGameLocalizationInfo().filter(@(value) requestedLangs.contains(value.id))
}

function startBuildWeaponsLocAsync(path, spec, langsInfo, curLang, locFileName, statusPath, runningState) {
  if (runningState.running) {
    logerr("weapons loc export rejected: another weapons export (DB or loc) is already running")
    return false
  }
  runningState.running = true

  let status = ExporterStatus(statusPath ?? "")
  let details = {
    state = "processing"
    totalLangsLen = langsInfo.len()
    leftLangsLen = langsInfo.len()
    processedLangs = []
    failedLangs = []
    outFiles = {}
  }
  status.setTargetDetails(TARGET_WEAPONS_LOC, details)

  let pending = clone langsInfo

  function safeFlushStatus() {
    try {
      status.forceFlushToFile()
    } catch (e) {
      logerr($"failed to write weapons loc status: {e}")
    }
  }

  safeFlushStatus()
  log($"building weapons loc: totalLangs={langsInfo.len()}")

  function finalize(isSuccess) {
    details.state = isSuccess ? "done" : "failed"
    details.leftLangsLen = pending.len()
    status.finishTarget(TARGET_WEAPONS_LOC, isSuccess)
    safeFlushStatus()
    runningState.running = false
    setGameLocalization(curLang, false, false)
    log($"DONE weapons loc: processed={details.processedLangs.len()} failed={details.failedLangs.len()}")
  }

  function stepImpl() {
    try {
      if (pending.len() == 0) {
        finalize(details.failedLangs.len() == 0)
        return
      }

      let lang = pending.pop()
      let langId = lang.id

      try {
        setGameLocalization(langId, false, false)
        let locTable = buildLocTableForCurLang(spec)
        let outFile = makeLocOutPath(path, locFileName, langId)
        mkpath(outFile)
        saveJson(outFile, locTable)
        details.processedLangs.append(langId)
        details.outFiles[langId] <- outFile
        log($"weapons loc saved: lang={langId} -> {outFile}")
      } catch (e) {
        logerr($"failed to build weapons loc for lang='{langId}': {e}")
        details.failedLangs.append(langId)
      }

      details.leftLangsLen = pending.len()

      if (pending.len() == 0) {
        finalize(details.failedLangs.len() == 0)
        return
      }

      defer(callee())
    } catch (e) {
      logerr($"weapons loc step failed unexpectedly: {e}")
      finalize(false)
    }
  }

  stepImpl()
  return true
}

function buildWeaponsLoc(params) {
  let exportDb = params?.exportDb
  let runningState = params?.runningState
  if (exportDb == null || runningState == null) {
    logerr("weapons loc: missing exportDb or runningState")
    return false
  }

  let langsInfo = resolveLangsInfo(params?.langs)
  if (langsInfo.len() == 0) {
    log("weapons loc: no matching languages, skipping")
    return false
  }

  let path = params?.path ?? "export"
  let locFileName = params?.locFileName ?? "weapons_loc.json"
  let statusPath = makePath(path, params?.locStatusFileName ?? "weapons_loc_status.json")
  let spec = collectLocSpec(exportDb)

  return startBuildWeaponsLocAsync(path, spec, langsInfo, params?.curLang, locFileName, statusPath, runningState)
}

return buildWeaponsLoc
