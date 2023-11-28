from "%scripts/dagui_library.nut" import *

let { getLocalLanguage } = require("language")
let u = require("%sqStdLibs/helpers/u.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let DataBlock  = require("DataBlock")
let { format } = require("string")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { UNIT_CONFIGURATION_MIN, UNIT_CONFIGURATION_MAX } = require("%scripts/unit/unitInfoType.nut")
let { export_calculations_parameters_for_wta } = require("unitCalculcation")
let { saveJson } = require("%sqstd/json.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { getGameLocalizationInfo, setGameLocalization } = require("%scripts/langUtils/language.nut")

const ARMY_GROUP = "army"
const COUNTRY_GROUP = "country"
const RANK_GROUP = "rank"
const COMMON_PARAMS_GROUP = "common"
const BASE_GROUP = "base"
const EXTENDED_GROUP = "extended"

let EXCLUDED_TAGS = ["type_exoskeleton"]

let class ExporterStatus {
  static DETAILS_FIELD = "details"
  static SUCCESS_FIELD = "success"

  lastFlushTimeMsec = -1

  flushPeriodMsec = 0
  filename = ""
  status = null

  constructor(filename_, flushPeriodMsec_ = 5000) {
    this.flushPeriodMsec = flushPeriodMsec_
    this.filename = filename_
    this.status = {}
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

let class UnitInfoExporter {
  static EXPORT_TIME_OUT = 20000
  static FRAME_TIME_OUT = 2000
  static activeUnitInfoExporters = []
  static TARGET_CALCULATION_PARAMETERS = "calculationParameters"
  lastActiveTime = -1

  path = "export"
  langsList = null

  langBeforeExport = ""
  curLang = ""

  debugLog = dlog // warning disable: -forbidden-function
  isToStringForDebug = true

  fullBlk = null
  unitsList = null

  status = null

  constructor(genLangsList = ["English", "Russian"], genPath = "export") { //null - export all langs
    if (!this.isReadyStartExporter())
      return

    this.activeUnitInfoExporters.append(this)
    this.updateActive()

    subscribe_handler(this)

    this.langBeforeExport = getLocalLanguage()
    if (u.isArray(genLangsList))
      this.langsList = clone genLangsList
    else if (u.isString(genLangsList))
      this.langsList = [genLangsList]
    else
      this.langsList = getGameLocalizationInfo().map(@(lang) lang.id)

    this.path = genPath
    this.status = ExporterStatus(this.getStatusFullPath())
    this.status.setTargetDetails(this.TARGET_CALCULATION_PARAMETERS, "waiting")
    foreach (lang in this.langsList)
      this.status.setTargetDetails(lang, "waiting")
    this.status.forceFlushToFile()

    this.exportCalculationParameters()
    get_main_gui_scene().performDelayed(this, this.nextLangExport)
  }

  function _tostring() {
    return format("Exporter(%s, '%s')", toString(this.langsList), this.path)
  }

  function isReadyStartExporter() {
    if (!this.activeUnitInfoExporters.len())
      return true

    if (this.activeUnitInfoExporters[0].isStuck()) {
      this.activeUnitInfoExporters[0].remove()
      return true
    }

    this.debugLog("Exporter: Error: Previous exporter not finish process")
    return false
  }

  function isValid() {
    foreach (_idx, exporter in this.activeUnitInfoExporters)
      if (exporter == this)
        return true
    return false
  }

  function isStuck() {
    return get_time_msec() - this.lastActiveTime > this.EXPORT_TIME_OUT
  }

  function isNeedFrame() {
    return get_time_msec() - this.lastActiveTime > this.FRAME_TIME_OUT
  }

  function updateActive() {
    this.lastActiveTime = get_time_msec()
  }

  function remove() {
    let auie = this.activeUnitInfoExporters
    let l = auie.len()
    for (local idx=l-1; idx>=0; --idx) {
      if (auie[idx] == this)
        auie.remove(idx)
     }

    setGameLocalization(this.langBeforeExport, false, false)
  }

  /******************************************************************************/
  /********************************EXPORT PROCESS********************************/
  /******************************************************************************/

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

  function nextLangExport() {
    if (this.curLang != "") {
      this.status.finishTarget(this.curLang, this.status.getTargetDetails(this.curLang).failedUnits.len() == 0)
      this.status.periodicFlushToFile()
    }

    if (!this.langsList.len()) {
      this.status.forceFlushToFile()
      this.remove()
      this.debugLog("Exporter: DONE.")
      return
    }

    this.curLang = this.langsList.pop()
    setGameLocalization(this.curLang, false, false)

    this.debugLog($"Exporter: gen all units info to {this.getLangFullPath()}")
    get_main_gui_scene().performDelayed(this, this.startExport) //delay to show exporter logs
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
    fBlk.saveToTextFile(this.getLangFullPath())
    get_main_gui_scene().performDelayed(this, this.nextLangExport) //delay to show exporter logs
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

    for (local rank = 1; rank <= ::max_country_rank; rank++)
      fBlk[RANK_GROUP]["texts"][rank.tostring()] = get_roman_numeral(rank)
  }

  function exportCommonParams(fBlk) {
    fBlk[COMMON_PARAMS_GROUP] = DataBlock()

    foreach (infoType in ::g_unit_info_type.types)
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
      get_main_gui_scene().performDelayed(this, this.onFrameRedrawnWhileExporting)
      return false
    }

    this.debugLog($"Exporter: process unit {curUnit.name}; {this.unitsList.len()} left")
    if (!curUnit.modificators || !curUnit.minChars || !curUnit.maxChars) {
      this.debugLog($"Exporter: wait for calculating parameters for unit {curUnit.name}")
      return ::check_unit_mods_update(curUnit, null, true, true)
    }

    let groupId = curUnit.showOnlyWhenBought ? EXTENDED_GROUP : BASE_GROUP

    let armyId = curUnit.unitType.armyId

    let countryId = curUnit.shopCountry

    if (countryId == null || countryId == "")
      return true;

    let rankId = curUnit.rank.tostring()

    let unitBlk = DataBlock()

    let configurations = [UNIT_CONFIGURATION_MIN, UNIT_CONFIGURATION_MAX]

    foreach (conf in configurations) {
      foreach (infoType in ::g_unit_info_type.types) {
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

let function exportUnitInfo(params) {
  UnitInfoExporter(params["langs"], params["path"])
  return "ok"
}

web_rpc.register_handler("exportUnitInfo", exportUnitInfo)