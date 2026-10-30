from "%scripts/langUtils/language.nut" import getGameLocalizationInfo
from "%scripts/langUtils/langJobs.nut" import registerLangJob, startLangJob
from "%sqstd/json.nut" import saveJson
from "dagor.fs" import mkpath
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_library.nut" import *
from "types" import Array

const TARGET_WEAPONS_LOC = "weaponsLoc"
const LANG_JOB_ID = "exportInfo.weaponsLocExporter"

class ExporterStatus {
  static DETAILS_FIELD = "details"
  static SUCCESS_FIELD = "success"

  filename = ""
  status = null

  constructor(filename_, status_) {
    this.filename = filename_
    this.status = status_
  }

  function setTargetField(target, field, value) {
    if (!(target in this.status))
      this.status[target] <- {}
    this.status[target][field] <- value
  }

  function setTargetDetails(target, details) {
    this.setTargetField(target, this.DETAILS_FIELD, details)
  }

  function getTargetDetails(target) {
    return this.status[target][this.DETAILS_FIELD]
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

function safeFlushStatus(status) {
  try {
    status.forceFlushToFile()
  } catch (e) {
    logerr($"failed to write weapons loc status: {e}")
  }
}

function buildLangLoc(lang, data, onDone) {
  let { path, locFileName, statusPath, spec } = data
  let details = ExporterStatus(statusPath, data.status).getTargetDetails(TARGET_WEAPONS_LOC)
  try {
    let locTable = buildLocTableForCurLang(spec)
    let outFile = makeLocOutPath(path, locFileName, lang)
    mkpath(outFile)
    saveJson(outFile, locTable)
    details.processedLangs.append(lang)
    details.outFiles[lang] <- outFile
    log($"weapons loc saved: lang={lang} -> {outFile}")
  } catch (e) {
    logerr($"failed to build weapons loc for lang='{lang}': {e}")
    details.failedLangs.append(lang)
  }
  details.leftLangsLen--
  onDone()
}

function finishWeaponsLoc(data) {
  let status = ExporterStatus(data.statusPath, data.status)
  let details = status.getTargetDetails(TARGET_WEAPONS_LOC)
  let isSuccess = details.leftLangsLen == 0 && details.failedLangs.len() == 0
  details.state = isSuccess ? "done" : "failed"
  status.finishTarget(TARGET_WEAPONS_LOC, isSuccess)
  safeFlushStatus(status)
  log($"DONE weapons loc: processed={details.processedLangs.len()} failed={details.failedLangs.len()}")
}

registerLangJob(LANG_JOB_ID, buildLangLoc, finishWeaponsLoc)

function buildWeaponsLoc(params) {
  let exportDb = params?.exportDb
  if (exportDb == null) {
    logerr("weapons loc: missing exportDb")
    return false
  }

  let langs = resolveLangsInfo(params?.langs).map(@(lang) lang.id)
  if (langs.len() == 0) {
    log("weapons loc: no matching languages, skipping")
    return false
  }

  let path = params?.path ?? "export"
  let jobData = {
    path
    locFileName = params?.locFileName ?? "weapons_loc.json"
    statusPath = makePath(path, params?.locStatusFileName ?? "weapons_loc_status.json")
    spec = collectLocSpec(exportDb)
    status = {}
  }
  let status = ExporterStatus(jobData.statusPath, jobData.status)
  status.setTargetDetails(TARGET_WEAPONS_LOC, {
    state = "processing"
    totalLangsLen = langs.len()
    leftLangsLen = langs.len()
    processedLangs = []
    failedLangs = []
    outFiles = {}
  })

  if (!startLangJob(LANG_JOB_ID, langs, jobData)) {
    status.getTargetDetails(TARGET_WEAPONS_LOC).state = "failed"
    status.finishTarget(TARGET_WEAPONS_LOC, false)
    safeFlushStatus(status)
    return false
  }
  safeFlushStatus(status)
  log($"building weapons loc: totalLangs={langs.len()}")
  return true
}

return buildWeaponsLoc
