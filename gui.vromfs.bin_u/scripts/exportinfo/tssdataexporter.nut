from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/langUtils/language.nut" import getGameLocalizationInfo
from "%scripts/langUtils/langJobs.nut" import registerLangJob, startLangJob, isLangJobRunning, setReloadUnsafeWork
from "%scripts/missions/missionsText.nut" import getCombineLocNameMission
from "%scripts/unit/unitInfo.nut" import getUnitName, image_for_air
from "%scripts/unit/unitInfoRoles.nut" import getUnitBasicRole
from "%scripts/unit/unitInfoTexts.nut" import getUnitTooltipImage, getUnitClassIco
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "dagor.fs" import mkdir
from "dagor.workcycle" import defer
from "dagor.time" import get_local_unixtime
from "app" import get_game_version_str
from "%sqstd/path.nut" import fileName
from "%sqstd/json.nut" import saveJson
from "%sqstd/datablock.nut" import blkFromPath
from "guiMission" import get_meta_missions_info
from "%scripts/dagui_library.nut" import *
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/webRPC.nut" import webRpcRegister

const LANG_JOB_ID = "exportInfo.tssDataExporter"

let exportState = mkHardPersist("exportInfo.tssDataExporter")("exportState", { isSuccessful = null })
local activeExporter = null

function debugLog(message) {
  
  
  dlog($"[TSS Exporter] {message}") 
}

function fileNameWithoutExt(path) {
  let nameWithExt = fileName(path)
  let nameParts = nameWithExt.split(".")
  return nameParts[0]
}

function getMissionsList() {
  let missionsList = get_meta_missions_info(GM_SKIRMISH)
    .filter(function (mission) {
      let misChapter = mission?.chapter

      return !["test", "hidden"].contains(misChapter)
    })

  return missionsList
}

function getUnitsList() {
  return getAllUnits()
    .filter(@(unit) unit.isInShop && !unit.isPkgDev)
    .values()
}

function finishExport(isSuccessful) {
  debugLog("Finish export")
  activeExporter = null
  setReloadUnsafeWork(LANG_JOB_ID, false)
  exportState.isSuccessful = isSuccessful
}


class ExporterForTss {
  currentStep = -1
  startTime = null

  outputDir = ""
  exportLangsList = []

  cachedData = {}

  constructor(langsList, outputDir) {
    let gameLocalizationInfo = getGameLocalizationInfo()

    local filteredLangs = gameLocalizationInfo.filter(@(value) langsList.contains(value.id))
    if (filteredLangs.len() == 0) {
      
      filteredLangs = gameLocalizationInfo
    }
    this.exportLangsList = filteredLangs.map(@(lang) lang.id)

    this.outputDir = outputDir
  }

  function start() {
    if (this.startTime)
      return

    this.startTime = get_local_unixtime()
    exportState.isSuccessful = null
    setReloadUnsafeWork(LANG_JOB_ID, true)
    debugLog("Start export")

    this.nextStep()
  }

  function getSteps() {
    return [
      this.fillMissionsList,
      this.fillUnitsList,
      this.makeMissionsInfo,
      this.makeUnitsInfo,
      this.makeLocData
    ]
  }

  function nextStep() {
    if (!this.startTime)
      return

    this.currentStep++
    let steps = this.getSteps()

    if (steps.len() <= this.currentStep) {
      finishExport(false)
      return
    }

    let stepFn = steps[this.currentStep]

    
    defer((function() {
      try {
        stepFn()
      } catch (e) {
        debugLog($"[ERROR] Step {this.currentStep} is broken | {e}")
        finishExport(false)
      }
    }).bindenv(this))
  }

  
  function fillMissionsList() {
    debugLog("Fill missions list")

    this.cachedData.missionsList <- getMissionsList()

    this.nextStep()
  }

  
  function makeMissionsInfo() {
    debugLog("Make missions info")

    let missionsInfo = []
    let missionsList = this.cachedData.missionsList

    foreach (mission in missionsList) {
      let missionName = mission.name
      debugLog($"Make mission info for {missionName}")

      let missionInfo = this.getMissionInfo(mission)
      missionsInfo.append(missionInfo)
    }
    this.cachedData.missionsInfo <- missionsInfo

    this.nextStep()
  }

  function getMissionInfo(mission) {
    let fullMisBlkFile = mission.mis_file
    let fullMisBlk = blkFromPath(fullMisBlkFile)

    let levelName = fullMisBlk.mission_settings.mission.level
    let levelBlk = blkFromPath($"{levelName.slice(0, -3)}blk")

    let rankSensitiveImports = this.findRankSensitiveImports(fullMisBlk)

    let mapCoord = levelBlk?.mapCoord0
      ? ( [[ levelBlk.mapCoord0.x, levelBlk.mapCoord0.y ],
           [ levelBlk.mapCoord1.x, levelBlk.mapCoord1.y ]] )
      : null

    let tankMapCoord = levelBlk?.tankMapCoord0
      ? ( [[ levelBlk.tankMapCoord0.x, levelBlk.tankMapCoord0.y ],
           [ levelBlk.tankMapCoord1.x, levelBlk.tankMapCoord1.y ]] )
      : null

    let missionInfo = {
      id = mission.name
      chapter = mission.chapter
      allowedUnitTypes = {
        isAirplanesAllowed = mission?.isAirplanesAllowed ?? false
        isHelicoptersAllowed = mission?.isHelicoptersAllowed ?? false
        isTanksAllowed = mission?.isTanksAllowed ?? false
        isShipsAllowed = mission?.isShipsAllowed ?? false
        isHumansAllowed = mission?.isHumansAllowed ?? false
        allowedKillStreaks = mission?.allowedKillStreaks ?? false
      }
      level = {
        levelName = fileNameWithoutExt(levelName)
        customLevelMap = levelBlk?.customLevelMap ?? ""
        customLevelTankMap = levelBlk?.customLevelTankMap ?? ""
        mapCoord = mapCoord
        tankMapCoord = tankMapCoord
      }
      rankSensitive = rankSensitiveImports
    }

    return missionInfo
  }

  
  
  function findRankSensitiveImports(blk, findNested = true) {
    if (!blk?.imports)
      return []

    let importRecords = blk.imports % "import_record"

    let rankSensitiveImports = []

    foreach (record in importRecords) {
      let importBlkFile = record?.file
      if (!importBlkFile)
        continue

      if ("rankRange" in record) {
        rankSensitiveImports.append({
          id = fileNameWithoutExt(importBlkFile)
          range = [record.rankRange.x, record.rankRange.y]
        })
      } else if (findNested) {
        let importBlk = blkFromPath(importBlkFile)
        let nestedRankSensitiveImports = this.findRankSensitiveImports(importBlk, false)
        rankSensitiveImports.extend(nestedRankSensitiveImports)
      }
    }

    return rankSensitiveImports
  }

   
  function fillUnitsList() {
    debugLog("Fill units list")

    this.cachedData.unitsList <- getUnitsList()

    this.nextStep()
  }

  
  function makeUnitsInfo() {
    debugLog("Make units info")

    let unitsList = this.cachedData.unitsList
    let unitsInfo = []
    foreach (unit in unitsList) {
      let unitInfo = this.getUnitInfo(unit)
      unitsInfo.append(unitInfo)
    }

    this.cachedData.unitsInfo <- unitsInfo

    this.nextStep()
  }

  function getUnitInfo(unit) {
    let unitInfo = {
      id = unit.name
      type = unit.esUnitType
      expType = unit.isSquadronVehicle()
        ? "squadron"
        : (isUnitSpecial(unit) ? "premium" : "regular")
      rank = unit.rank
      country = unit.shopCountry
      role = getUnitBasicRole(unit)
      restrict = unit.hideBrForVehicle || unit.showShortestUnitInfo || unit.isSlave()
      images = {
        fullImage = getUnitTooltipImage(unit)
        treeImage = image_for_air(unit)
        svgIcon = getUnitClassIco(unit)
      }
    }

    return unitInfo
  }

  
  function makeLocData() {
    debugLog("Make loc data")

    let { missionsInfo, unitsInfo } = this.cachedData
    let jobData = {
      outputDir = this.outputDir
      startTime = this.startTime
      missionsInfo
      unitsInfo
      locData = {}
      leftLangsLen = this.exportLangsList.len()
    }
    activeExporter = null
    setReloadUnsafeWork(LANG_JOB_ID, false)
    if (!startLangJob(LANG_JOB_ID, this.exportLangsList, jobData))
      finishExport(false)
  }
}

function langsForMissions(curLang, locData) {
  if (!("missions" in locData)) {
    locData["missions"] <- {}
  }

  foreach (mission in getMissionsList()) {
    let missionId = mission.name
    let missionLocName = getCombineLocNameMission(mission)

    if (!(missionId in locData["missions"])) {
      locData["missions"][missionId] <- {}
    }

    locData["missions"][missionId][curLang] <- missionLocName
  }
}

function langsForUnits(curLang, locData) {
  if (!("units" in locData)) {
    locData["units"] <- {}
  }

  foreach (unit in getUnitsList()) {
    let unitId = unit.name
    let unitLocName = getUnitName(unit)

    if (!(unitId in locData["units"])) {
      locData["units"][unitId] <- {}
    }

    locData["units"][unitId][curLang] <- unitLocName
  }
}

function processLang(lang, data, onDone) {
  debugLog($"Processing lang {lang}")

  try {
    langsForMissions(lang, data.locData)
    langsForUnits(lang, data.locData)
    data.leftLangsLen--
  } catch (e) {
    debugLog($"[ERROR] Processing lang is broken | {e}")
  }
  onDone()
}

function saveExportData(outputDir, exportData) {
  debugLog("Save export data")

  mkdir(outputDir)

  saveJson(
    $"{outputDir}/export_tss.json",
    exportData,
    {pretty_print=false}
  )
}


function buildExportData(data) {
  debugLog("Build export data")

  let { missionsInfo, unitsInfo, locData } = data
  foreach (info in missionsInfo)
    info.loc <- locData?.missions?[info.id] ?? {}
  foreach (info in unitsInfo)
    info.loc <- locData?.units?[info.id] ?? {}

  let exportData = {
    missions = missionsInfo
    units = unitsInfo
    version = get_game_version_str()
    timestamp = data.startTime
  }

  saveExportData(data.outputDir, exportData)
}

function finishLangs(data) {
  if (data.leftLangsLen != 0) {
    finishExport(false)
    return
  }

  try {
    buildExportData(data)
  } catch (e) {
    debugLog($"[ERROR] Build export data is broken | {e}")
    finishExport(false)
    return
  }
  finishExport(true)
}

registerLangJob(LANG_JOB_ID, processLang, finishLangs)

function handlerExportForTss(params) {
  
  let isForceStart = params?.forced ?? false
  if (activeExporter?.startTime || isLangJobRunning(LANG_JOB_ID)) {
    return "in progress"
  } else if (exportState.isSuccessful != null && !isForceStart) {
    if (exportState.isSuccessful) {
      return "finished | success"
    } else {
      return "finished | error"
    }
  }
  
  if (isLangJobRunning())
    return "error: a language job is running"

  let { langs, path } = params
  activeExporter = ExporterForTss(langs, path)
  activeExporter.start()

  return "started"
}

webRpcRegister("exportForTss", handlerExportForTss)
