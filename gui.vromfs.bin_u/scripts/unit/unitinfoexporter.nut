from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let {UNIT_CONFIGURATION_MIN, UNIT_CONFIGURATION_MAX} = require("%scripts/unit/unitInfoType.nut")
let { export_calculations_parameters_for_wta } = require("unitCalculcation")

const COUNTRY_GROUP = "country"
global const ARMY_GROUP = "army"
const RANK_GROUP = "rank"
const COMMON_PARAMS_GROUP = "common"
const BASE_GROUP = "base"
const EXTENDED_GROUP = "extended"

let class UnitInfoExporter
{
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

  constructor(genLangsList = ["English", "Russian"], genPath = "export") //null - export all langs
  {
    if (!isReadyStartExporter())
      return

    activeUnitInfoExporters.append(this)
    updateActive()

    ::subscribe_handler(this)

    langBeforeExport = ::get_current_language()
    if (::u.isArray(genLangsList))
      langsList = clone genLangsList
    else if (::u.isString(genLangsList))
      langsList = [genLangsList]
    else
      langsList = ::u.map(::g_language.getGameLocalizationInfo(), function(lang) { return lang.id })

    path = genPath

    exportCalculationParameters()
    ::get_main_gui_scene().performDelayed(this, nextLangExport)
  }

  function _tostring()
  {
    return format("Exporter(%s, '%s')", toString(langsList), path)
  }

  function isReadyStartExporter()
  {
    if (!activeUnitInfoExporters.len())
      return true

    if (activeUnitInfoExporters[0].isStuck())
    {
      activeUnitInfoExporters[0].remove()
      return true
    }

    debugLog("Exporter: Error: Previous exporter not finish process")
    return false
  }

  function isValid()
  {
    foreach(idx, exporter in activeUnitInfoExporters)
      if (exporter == this)
        return true
    return false
  }

  function isStuck()
  {
    return ::dagor.getCurTime() - lastActiveTime < EXPORT_TIME_OUT
  }

  function updateActive()
  {
    lastActiveTime = ::dagor.getCurTime()
  }

  function remove()
  {
    foreach(idx, exporter in activeUnitInfoExporters)
      if (exporter == this)
        activeUnitInfoExporters.remove(idx)

    ::g_language.setGameLocalization(langBeforeExport, false, false)
  }

  /******************************************************************************/
  /********************************EXPORT PROCESS********************************/
  /******************************************************************************/

  function exportCalculationParameters() {
    debugLog("Exporter: start fetching calculation parameters")
    let shopUnitsNames = ::all_units
      .filter(@(unit) unit.isInShop)
      .map(@(unit) unit.name)
      .values()
    let instance = this
    export_calculations_parameters_for_wta(shopUnitsNames, function(parameters) {
      instance.debugLog("Exporter: calculation parameters received")
      parameters.saveToTextFile(instance.getCalculationParemetersFullPath())
    })
  }

  function nextLangExport()
  {
    if (!langsList.len())
    {
      remove()
      debugLog("Exporter: DONE.")
      return
    }

    curLang = langsList.pop()
    ::g_language.setGameLocalization(curLang, false, false)

    debugLog($"Exporter: gen all units info to {getLangFullPath()}")
    ::get_main_gui_scene().performDelayed(this, startExport) //delay to show exporter logs
  }

  function getCalculationParemetersFullPath() {
    let relPath = ::u.isEmpty(path) ? "" : $"{path}/"
    return format("%scalculationParameters.blk", relPath)
  }

  function getLangFullPath()
  {
    let relPath = ::u.isEmpty(path) ? "" : $"{path}/"
    return format("%sunitInfo%s.blk", relPath, curLang)
  }

  function startExport()
  {
    debugLog($"Exporter: start export for lang {curLang}")
    fullBlk = ::DataBlock()
    exportUnitType(fullBlk)
    exportCountry(fullBlk)
    exportRank(fullBlk)
    exportCommonParams(fullBlk)

    fullBlk[BASE_GROUP] = ::DataBlock()
    fullBlk[EXTENDED_GROUP] = ::DataBlock()

    unitsList = ::all_units.values()

    updateActive()

    processUnits()
  }

  function finishExport(fBlk)
  {
    fBlk.saveToTextFile(getLangFullPath())
    ::get_main_gui_scene().performDelayed(this, nextLangExport) //delay to show exporter logs
  }

  function exportUnitType(fBlk)
  {
    fBlk[ARMY_GROUP] = ::DataBlock()

    foreach(unitType in unitTypes.types)
      if (unitType != unitTypes.INVALID)
        fBlk[ARMY_GROUP][unitType.armyId] = unitType.getArmyLocName()
  }

  function exportCountry(fBlk)
  {
    fBlk[COUNTRY_GROUP] = ::DataBlock()

    foreach(country in shopCountriesList)
      fBlk[COUNTRY_GROUP][country] = loc(country)
  }

  function exportRank(fBlk)
  {
    fBlk[RANK_GROUP] = ::DataBlock()
    fBlk[RANK_GROUP].header = loc("shop/age")
    fBlk[RANK_GROUP].texts = ::DataBlock()

    for(local rank = 1; rank <= ::max_country_rank; rank++)
      fBlk[RANK_GROUP]["texts"][rank.tostring()] = ::get_roman_numeral(rank)
  }

  function exportCommonParams(fBlk)
  {
    fBlk[COMMON_PARAMS_GROUP] = ::DataBlock()

    foreach(infoType in ::g_unit_info_type.types)
      fBlk[COMMON_PARAMS_GROUP][infoType.id] = infoType.exportCommonToDataBlock()
  }

  function onEventUnitModsRecount(params)
  {
    processUnits()
  }

  function processUnits()
  {
    while (unitsList.len())
    {
        if(!exportCurUnit(fullBlk, unitsList[unitsList.len() - 1]))
          return
        unitsList.pop()
    }
    finishExport(fullBlk)
  }

  function exportCurUnit(fBlk, curUnit)
  {
    if (!curUnit.isInShop)
      return true

    debugLog($"Exporter: process unit {curUnit.name}; {unitsList.len()} left")
    if (!curUnit.modificators || !curUnit.minChars || !curUnit.maxChars)
    {
      debugLog($"Exporter: wait for calculating parameters for unit {curUnit.name}")
      return ::check_unit_mods_update(curUnit, null, true, true)
    }

    let groupId = curUnit.showOnlyWhenBought? EXTENDED_GROUP : BASE_GROUP

    let armyId = curUnit.unitType.armyId

    let countryId = curUnit.shopCountry

    if(countryId == null || countryId == "")
      return true;

    let rankId = curUnit.rank.tostring()

    let unitBlk = ::DataBlock()

    let configurations = [UNIT_CONFIGURATION_MIN, UNIT_CONFIGURATION_MAX]

    foreach (conf in configurations) {
      foreach(infoType in ::g_unit_info_type.types)
      {
        let blk = infoType.exportToDataBlock(curUnit, conf)
        if(blk?.hide ?? false)
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

let function exportUnitInfo(params)
{
  UnitInfoExporter(params["langs"], params["path"])
  return "ok"
}

::web_rpc.register_handler("exportUnitInfo", exportUnitInfo)