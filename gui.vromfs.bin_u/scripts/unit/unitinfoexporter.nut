from "%scripts/unit/unitsData.nut" import getAllUnits
import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/unit/unitInfoType.nut" import UNIT_CONFIGURATION_MIN, UNIT_CONFIGURATION_MAX, processWeaponPresets, processWeaponPilons
from "%scripts/unit/unitChecks.nut" import checkUnitModsUpdate
from "%scripts/langUtils/language.nut" import getGameLocalizationInfo
from "%scripts/langUtils/langJobs.nut" import registerLangJob, startLangJob, touchLangJob
from "%scripts/ranks.nut" import maxCountryRank
from "%scripts/weaponry/weaponryDescription.nut" import getWeaponNameText
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler
from "dagor.time" import get_time_msec
from "dagor.workcycle" import defer
from "string" import format
from "unitCalculcation" import export_calculations_parameters_for_wta
from "%sqstd/json.nut" import saveJson
from "console" import register_command
from "%scripts/dagui_library.nut" import *
from "%scripts/webRPC.nut" import webRpcRegister

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { g_unit_info_type } = require("%scripts/unit/unitInfoType.nut")

const ARMY_GROUP = "army"
const COUNTRY_GROUP = "country"
const RANK_GROUP = "rank"
const COMMON_PARAMS_GROUP = "common"
const BASE_GROUP = "base"
const EXTENDED_GROUP = "extended"

let EXCLUDED_TAGS = ["type_exoskeleton"]

class ExporterStatus {
  static DETAILS_FIELD = "details"
  static SUCCESS_FIELD = "success"

  lastFlushTimeMsec = -1

  flushPeriodMsec = 0
  filename = ""
  status = null

  constructor(filename_, status_, flushPeriodMsec_ = 5000) {
    this.flushPeriodMsec = flushPeriodMsec_
    this.filename = filename_
    this.status = status_
  }

  function getTargetStatus(target) {
    if (!(target in this.status))
      this.status[target] <- {}
    return this.status[target]
  }

  function setTargetDetails(target, details) {
    this.getTargetStatus(target)[this.DETAILS_FIELD] <- details
  }

  function getTargetDetails(target) {
    return this.getTargetStatus(target)[this.DETAILS_FIELD]
  }

  function finishTarget(target, isSuccess) {
    this.getTargetStatus(target)[this.SUCCESS_FIELD] <- isSuccess
  }

  function periodicFlushToFile() {
    if (this.lastFlushTimeMsec + this.flushPeriodMsec < get_time_msec())
      this.forceFlushToFile()
  }

  function forceFlushToFile() {
    this.lastFlushTimeMsec = get_time_msec()
    saveJson(this.filename, this.status)
  }
}

class UnitInfoExporter {
  static FRAME_TIME_OUT = 2000
  static TARGET_CALCULATION_PARAMETERS = "calculationParameters"
  lastActiveTime = -1

  path = "export"
  curLang = ""
  onDone = null

  debugLog = dlog 
  isToStringForDebug = true

  fullBlk = null
  unitsList = null

  presetLocs = null

  status = null

  constructor(jobData) {
    this.path = jobData.path
    this.status = ExporterStatus(this.getStatusFullPath(), jobData.status)
  }

  function _tostring() {
    return format("Exporter('%s', '%s')", this.curLang, this.path)
  }

  function isValid() {
    return this.onDone != null
  }

  function isNeedFrame() {
    return get_time_msec() - this.lastActiveTime > this.FRAME_TIME_OUT
  }

  function updateActive() {
    this.lastActiveTime = get_time_msec()
    touchLangJob()
  }

  
  
  

  function exportCalculationParameters() {
    this.debugLog("Exporter: start fetching calculation parameters")
    try {
      let shopUnitsNames = getAllUnits()
        .filter(this.filterUnit)
        .map(@(unit) unit.name)
        .values()
      let instance = this
      this.status.setTargetDetails(this.TARGET_CALCULATION_PARAMETERS, "exporting")
      this.status.periodicFlushToFile()
      export_calculations_parameters_for_wta(shopUnitsNames, function(parameters) {
        instance.debugLog("Exporter: calculation parameters received")
        parameters.saveToTextFile(instance.getCalculationParemetersFullPath())
      })
      this.status.setTargetDetails(this.TARGET_CALCULATION_PARAMETERS, "done")
      this.status.finishTarget(this.TARGET_CALCULATION_PARAMETERS, true)
      this.status.periodicFlushToFile()
    } catch (e) {
      this.debugLog("Exporter: calculation parameters were failed with exception")
      this.status.setTargetDetails(this.TARGET_CALCULATION_PARAMETERS, "failed with exception")
      this.status.finishTarget(this.TARGET_CALCULATION_PARAMETERS, false)
      this.status.periodicFlushToFile()
    }
  }

  function startLangExport(lang, onDone) {
    this.curLang = lang
    this.onDone = onDone
    this.updateActive()
    subscribe_handler(this)

    this.debugLog($"Exporter: gen all units info to {this.getLangFullPath()}")
    let exporter = this
    defer(@() exporter.startExport()) 
  }

  function finishLangExport() {
    if (this.onDone == null)
      return
    this.status.finishTarget(this.curLang, this.status.getTargetDetails(this.curLang).failedUnits.len() == 0)
    this.status.periodicFlushToFile()
    let onDone = this.onDone
    this.onDone = null
    onDone()
  }

  function getCalculationParemetersFullPath() {
    let relPath = u.isEmpty(this.path) ? "" : $"{this.path}/"
    return format("%scalculationParameters.blk", relPath)
  }

  function getLangFullPath() {
    let relPath = u.isEmpty(this.path) ? "" : $"{this.path}/"
    return format("%sunitInfo%s.blk", relPath, this.curLang)
  }

  function getStatusFullPath() {
    let relPath = u.isEmpty(this.path) ? "" : $"{this.path}/"
    return format("%sstatus.json", relPath)
  }

  function startExport() {
    this.debugLog($"Exporter: start export for lang {this.curLang}")
    this.fullBlk = DataBlock()
    this.exportUnitType(this.fullBlk)
    this.exportCountry(this.fullBlk)
    this.exportRank(this.fullBlk)
    this.exportCommonParams(this.fullBlk)

    this.fullBlk[BASE_GROUP] = DataBlock()
    this.fullBlk[EXTENDED_GROUP] = DataBlock()

    this.unitsList = getAllUnits().values()

    this.presetLocs = DataBlock()

    this.updateActive()
    this.status.setTargetDetails(this.curLang, {
      totalUnitsLen = this.unitsList.len()
      leftUnitsLen = this.unitsList.len()
      failedUnits = []
    })
    this.status.periodicFlushToFile()

    this.processUnits()
  }

  function finishExport(fBlk) {
    fBlk["preset_locs"] = this.presetLocs
    fBlk.saveToTextFile(this.getLangFullPath())
    let exporter = this
    defer(@() exporter.finishLangExport()) 
  }

  function exportUnitType(fBlk) {
    fBlk[ARMY_GROUP] = DataBlock()

    foreach (unitType in unitTypes.types)
      if (unitType != unitTypes.INVALID)
        fBlk[ARMY_GROUP][unitType.armyId] = unitType.getArmyLocName()
  }

  function exportCountry(fBlk) {
    fBlk[COUNTRY_GROUP] = DataBlock()

    foreach (country in shopCountriesList)
      fBlk[COUNTRY_GROUP][country] = loc(country)
  }

  function exportRank(fBlk) {
    fBlk[RANK_GROUP] = DataBlock()
    fBlk[RANK_GROUP].header = loc("shop/age")
    fBlk[RANK_GROUP].texts = DataBlock()

    let maxRank = maxCountryRank.get()
    for (local rank = 1; rank <= maxRank; rank++)
      fBlk[RANK_GROUP]["texts"][rank.tostring()] = get_roman_numeral(rank)
  }

  function exportCommonParams(fBlk) {
    fBlk[COMMON_PARAMS_GROUP] = DataBlock()

    foreach (infoType in g_unit_info_type.types)
      fBlk[COMMON_PARAMS_GROUP][infoType.id] = infoType.exportCommonToDataBlock()
  }

  function onFrameRedrawnWhileExporting() {
    this.updateActive()
    this.processUnits()
  }

  function onEventUnitModsRecount(_params) {
    this.processUnits()
  }

  function processUnits() {
    while (this.unitsList.len()) {
        let curUnit = this.unitsList[this.unitsList.len() - 1]
        try {
          if (!this.exportCurUnit(this.fullBlk, curUnit))
            return
        } catch (e) {
          this.debugLog($"Exporter: exception was thrown while exporting unit '{curUnit.name}' on lang '{this.curLang}'")
          this.status.getTargetDetails(this.curLang).failedUnits.append(curUnit.name)
        }
        this.unitsList.pop()
        this.status.getTargetDetails(this.curLang).leftUnitsLen = this.unitsList.len()
        this.status.periodicFlushToFile()
    }
    this.finishExport(this.fullBlk)
  }

  function exportCurUnit(fBlk, curUnit) {
    if (!this.filterUnit(curUnit))
      return true

    if (this.isNeedFrame()) {
      let exporter = this
      defer(@() exporter.onFrameRedrawnWhileExporting())
      return false
    }

    this.debugLog($"Exporter: process unit {curUnit.name}; {this.unitsList.len()} left")
    if (!curUnit.modificators || !curUnit.minChars || !curUnit.maxChars) {
      this.debugLog($"Exporter: wait for calculating parameters for unit {curUnit.name}")
      return checkUnitModsUpdate(curUnit, null, true, true)
    }

    let groupId = curUnit.showOnlyWhenBought || curUnit.showOnlyWhenResearch ? EXTENDED_GROUP : BASE_GROUP

    let armyId = curUnit.unitType.armyId

    let countryId = curUnit.shopCountry

    if (countryId == null || countryId == "")
      return true;

    let rankId = curUnit.rank.tostring()

    let unitBlk = DataBlock()
    unitBlk.preset_locs = DataBlock()
    let presetsInfo = curUnit.getWeapons()
    foreach (preset in presetsInfo) {
      let displayName = getWeaponNameText(curUnit.name, false, preset.name, ", ")
      unitBlk.preset_locs[preset.name] = displayName
      this.presetLocs[preset.name] = displayName
    }

    let configurations = [UNIT_CONFIGURATION_MIN, UNIT_CONFIGURATION_MAX]

    foreach (conf in configurations) {
      foreach (infoType in g_unit_info_type.types) {
        let blk = infoType.exportToDataBlock(curUnit, conf)
        if (blk?.hide ?? false)
          continue
        unitBlk[infoType.id] = blk
      }
      let confGroup = conf == UNIT_CONFIGURATION_MIN ? "min" : "max"
      let targetBlk = fBlk.addBlock(confGroup).addBlock(groupId).addBlock(armyId).addBlock(countryId).addBlock(rankId)
      targetBlk[curUnit.name] = unitBlk
    }

    return true
  }

  function filterUnit(unit) {
    foreach (tag in EXCLUDED_TAGS)
      if (unit?.tags.contains(tag))
        return false
    return unit.isInShop
  }
}

const LANG_JOB_ID = "unit.unitInfoExporter"


local langExporter = null

function finishUnitInfoExport(jobData) {
  langExporter = null
  let exporter = UnitInfoExporter(jobData)
  exporter.status.forceFlushToFile()
  exporter.debugLog("Exporter: DONE.")
}

registerLangJob(LANG_JOB_ID, function(lang, jobData, onDone) {
  langExporter = UnitInfoExporter(jobData)
  langExporter.startLangExport(lang, onDone)
}, finishUnitInfoExport)

function exportUnitInfo(params) {
  let genLangsList = params["langs"]
  let langsList = u.isArray(genLangsList) ? genLangsList
    : u.isString(genLangsList) ? [genLangsList]
    : getGameLocalizationInfo().map(@(lang) lang.id) 
  let jobData = { path = params["path"], status = {} }
  if (startLangJob(LANG_JOB_ID, langsList, jobData)) {
    let exporter = UnitInfoExporter(jobData)
    exporter.status.setTargetDetails(exporter.TARGET_CALCULATION_PARAMETERS, "waiting")
    foreach (lang in langsList)
      exporter.status.setTargetDetails(lang, "waiting")
    exporter.status.forceFlushToFile()
    exporter.exportCalculationParameters()
  }
  return "ok"
}

function printUnitPresetsInfo(unitName) {
  let debugLog = dlog 
  processWeaponPresets(unitName, debugLog)
}

function printWeaponPilonsInfo(unitName) {
  let debugLog = dlog 
  processWeaponPilons(unitName, debugLog)
}

webRpcRegister("exportUnitInfo", exportUnitInfo)

register_command(@(unitName) printUnitPresetsInfo(unitName), "debug.print_unit_presets")
register_command(@(unitName) printWeaponPilonsInfo(unitName), "debug.print_pilons")
