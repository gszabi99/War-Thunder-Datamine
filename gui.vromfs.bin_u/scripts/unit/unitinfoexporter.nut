//checked for plus_string
from "%scripts/dagui_library.nut" import *
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

const COUNTRY_GROUP = "country"
const RANK_GROUP = "rank"
const COMMON_PARAMS_GROUP = "common"
const BASE_GROUP = "base"
const EXTENDED_GROUP = "extended"

let class UnitInfoExporter {
  static EXPORT_TIME_OUT = 20000
  static activeUnitInfoExporters = []
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

    this.status = {}
    this.activeUnitInfoExporters.append(this)
    this.updateActive()

    subscribe_handler(this)

    this.langBeforeExport = ::get_current_language()
    if (u.isArray(genLangsList))
      this.langsList = clone genLangsList
    else if (u.isString(genLangsList))
      this.langsList = [genLangsList]
    else
      this.langsList = u.map(::g_language.getGameLocalizationInfo(), function(lang) { return lang.id })

    this.path = genPath

    this.exportCalculationParameters()
    ::get_main_gui_scene().performDelayed(this, this.nextLangExport)
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
    return get_time_msec() - this.lastActiveTime < this.EXPORT_TIME_OUT
  }

  function updateActive() {
    this.lastActiveTime = get_time_msec()
  }

  function remove() {
    foreach (idx, exporter in this.activeUnitInfoExporters)
      if (exporter == this)
        this.activeUnitInfoExporters.remove(idx)

    ::g_language.setGameLocalization(this.langBeforeExport, false, false)
  }

  /******************************************************************************/
  /********************************EXPORT PROCESS********************************/
  /******************************************************************************/

  function getTargetStatus(target) {
    if (!(target in this.status))
      this.status[target] <- {}
    return this.status[target]
  }

  function exportCalculationParameters() {
    this.debugLog("Exporter: start fetching calculation parameters")
    try {
      let shopUnitsNames = ::all_units
        .filter(@(unit) unit.isInShop)
        .map(@(unit) unit.name)
        .values()
      let instance = this
      export_calculations_parameters_for_wta(shopUnitsNames, function(parameters) {
        instance.debugLog("Exporter: calculation parameters received")
        parameters.saveToTextFile(instance.getCalculationParemetersFullPath())
      })
      this.getTargetStatus("calculationParameters").success <- true
    } catch (e) {
      this.debugLog("Exporter: calculation parameters were failed with exception")
      this.getTargetStatus("calculationParameters").success <- false
    }
  }

  function nextLangExport() {
    if (this.curLang != "") {
      let targetStatus = this.getTargetStatus(this.curLang)
      targetStatus.success <- targetStatus.len() ? false : true
    }

    if (!this.langsList.len()) {
      saveJson(this.getStatusFullPath(), this.status)
      this.remove()
      this.debugLog("Exporter: DONE.")
      return
    }

    this.curLang = this.langsList.pop()
    ::g_language.setGameLocalization(this.curLang, false, false)

    this.debugLog($"Exporter: gen all units info to {this.getLangFullPath()}")
    ::get_main_gui_scene().performDelayed(this, this.startExport) //delay to show exporter logs
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

    this.unitsList = ::all_units.values()

    this.updateActive()

    this.processUnits()
  }

  function finishExport(fBlk) {
    fBlk.saveToTextFile(this.getLangFullPath())
    ::get_main_gui_scene().performDelayed(this, this.nextLangExport) //delay to show exporter logs
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
      fBlk[RANK_GROUP]["texts"][rank.tostring()] = ::get_roman_numeral(rank)
  }

  function exportCommonParams(fBlk) {
    fBlk[COMMON_PARAMS_GROUP] = DataBlock()

    foreach (infoType in ::g_unit_info_type.types)
      fBlk[COMMON_PARAMS_GROUP][infoType.id] = infoType.exportCommonToDataBlock()
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
          this.getTargetStatus(this.curLang)[curUnit.name] <- false
        }
        this.unitsList.pop()
    }
    this.finishExport(this.fullBlk)
  }

  function exportCurUnit(fBlk, curUnit) {
    if (!curUnit.isInShop)
      return true

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
}

let function exportUnitInfo(params) {
  UnitInfoExporter(params["langs"], params["path"])
  return "ok"
}

::web_rpc.register_handler("exportUnitInfo", exportUnitInfo)