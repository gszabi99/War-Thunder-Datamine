from "%scripts/dagui_library.nut" import *

let { mkdir } = require("dagor.fs")
let { defer } = require("dagor.workcycle")
let { get_local_unixtime } = require("dagor.time")

let { get_game_version_str } = require("app")

let { fileName } = require("%sqstd/path.nut")
let { saveJson } = require("%sqstd/json.nut")
let { blkFromPath } = require("%sqstd/datablock.nut")

let { web_rpc } = require("%scripts/webRPC.nut")
let { getLocalLanguage } = require("language")
let { getGameLocalizationInfo, setGameLocalization } = require("%scripts/langUtils/language.nut")

let { get_meta_missions_info } = require("guiMission")
let { getCombineLocNameMission } = require("%scripts/missions/missionsText.nut")

let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitName, image_for_air } = require("%scripts/unit/unitInfo.nut")
let { getUnitBasicRole } = require("%scripts/unit/unitInfoRoles.nut")
let { getUnitTooltipImage, getUnitClassIco } = require("%scripts/unit/unitInfoTexts.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")

local activeExporter = null

function fileNameWithoutExt(path) {
  let nameWithExt = fileName(path)
  let nameParts = nameWithExt.split(".")
  return nameParts[0]
}


let class ExporterForTss {
  currentStep = -1
  startTime = null
  isSuccessful = null

  outputDir = ""
  initialLang = ""
  exportLangsList = []

  debugLog = function(message) {
    
    
    dlog($"[TSS Exporter] {message}") 
  }

  cachedData = {}

  constructor(langsList, outputDir) {
    this.initialLang = getLocalLanguage()
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
    this.isSuccessful = null
    this.debugLog("Start export")

    this.nextStep()
  }

  function getSteps() {
    return [
      this.fillMissionsList,
      this.fillUnitsList,
      this.makeLocData,
      this.makeMissionsInfo,
      this.makeUnitsInfo,
      this.buildExportData,
      this.finish
    ]
  }

  function nextStep() {
    if (!this.startTime)
      return

    this.currentStep++
    let steps = this.getSteps()

    if (steps.len() <= this.currentStep) {
      this.finish(false)
      return
    }

    let stepFn = steps[this.currentStep]

    
    defer((function() {
      try {
        stepFn()
      } catch (e) {
        this.debugLog($"[ERROR] Step {this.currentStep} is broken | {e}")
        this.finish(false)
      }
    }).bindenv(this))
  }

  
  function fillMissionsList() {
    this.debugLog("Fill missions list")

    let missionsList = this.getMissionsList()
    this.cachedData.missionsList <- missionsList

    this.nextStep()
  }

  function getMissionsList() {
    let missionsList = get_meta_missions_info(GM_SKIRMISH)
      .filter(function (mission) {
        let misChapter = mission?.chapter

        return !["test", "hidden"].contains(misChapter)
      })

    return missionsList
  }

  
  function makeMissionsInfo() {
    this.debugLog("Make missions info")

    let missionsInfo = []
    let missionsList = this.cachedData.missionsList

    foreach (mission in missionsList) {
      let missionName = mission.name
      this.debugLog($"Make mission info for {missionName}")

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

    let locData = this.cachedData?.locData?.missions ?? {}

    let missionInfo = {
      id = mission.name
      loc = locData?[mission.name] ?? {}
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
    this.debugLog("Fill units list")

    let unitsList = getAllUnits()
      .filter(@(unit) unit.isInShop && !unit.isPkgDev)
      .values()
    this.cachedData.unitsList <- unitsList

    this.nextStep()
  }

  
  function makeUnitsInfo() {
    this.debugLog("Make units info")

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
    let locData = this.cachedData?.locData?.units ?? {}

    let unitInfo = {
      id = unit.name
      loc = locData?[unit.name] ?? {}
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
    this.debugLog("Make loc data")

    let langsList = clone this.exportLangsList
    let locData = {}

    defer((function() {
      this.processNextLang(langsList, locData)
    }).bindenv(this))
  }

  function processNextLang(langsList, locData) {
    let curLang = langsList.pop()
    this.debugLog($"Processing lang {curLang}")

    try {
      setGameLocalization(curLang, false, false)

      this.langsForMissions(curLang, locData)
      this.langsForUnits(curLang, locData)
    } catch (e) {
      this.debugLog($"[ERROR] Processing lang is broken | {e}")
      this.finish(false)
    }

    if (langsList.len() == 0) {
      this.finishLangProcessing(locData)
    } else {
      defer((function() {
        this.processNextLang(langsList, locData)
      }).bindenv(this))
    }
  }

  function langsForMissions(curLang, locData) {
    if (!("missions" in locData)) {
      locData["missions"] <- {}
    }

    let missionsList = this.cachedData.missionsList
    foreach (mission in missionsList) {
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

    let unitsList = this.cachedData.unitsList
    foreach (unit in unitsList) {
      let unitId = unit.name
      let unitLocName = getUnitName(unit)

      if (!(unitId in locData["units"])) {
        locData["units"][unitId] <- {}
      }

      locData["units"][unitId][curLang] <- unitLocName
    }
  }

  function finishLangProcessing(locData) {
    this.cachedData.locData <- locData
    this.nextStep()
  }

  
  function buildExportData() {
    this.debugLog("Build export data")

    let missionsInfo = this.cachedData.missionsInfo
    let unitsInfo = this.cachedData.unitsInfo

    let exportData = {
      missions = missionsInfo
      units = unitsInfo
      version = get_game_version_str()
      timestamp = this.startTime
    }

    this.saveExportData(exportData)

    this.nextStep()
  }

  function saveExportData(exportData) {
    this.debugLog("Save export data")

    mkdir(this.outputDir)

    saveJson(
      $"{this.outputDir}/export_tss.json",
      exportData,
      {pretty_print=false}
    )
  }

  
  function finish(isSuccessful = true) {
    try {
      this.debugLog($"Return initial locale {this.initialLang}")
      setGameLocalization(this.initialLang, false, false)
    } catch (e) {
      this.debugLog($"[ERROR] Return initial locale is broken | {e}")
      isSuccessful = false
    }

    this.debugLog("Finish export")

    this.cachedData = {}
    this.startTime = null
    this.currentStep = -1
    this.isSuccessful = isSuccessful
  }
}

function handlerExportForTss(params) {
  
  let isForceStart = params?.forced ?? false
  if (activeExporter?.startTime) {
    return "in progress"
  } else if (activeExporter?.isSuccessful != null && !isForceStart) {
    if (activeExporter?.isSuccessful) {
      return "finished | success"
    } else {
      return "finished | error"
    }
  }

  let { langs, path } = params
  activeExporter = ExporterForTss(langs, path)
  activeExporter.start()

  return "started"
}

web_rpc.register_handler("exportForTss", handlerExportForTss)
