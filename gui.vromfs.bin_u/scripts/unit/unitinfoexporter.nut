local unitTypes = require("scripts/unit/unitTypesList.nut")

::exportUnitInfo <- function exportUnitInfo(params)
{
    UnitInfoExporter(params["langs"], params["path"])
    return "ok"
}

const COUNTRY_GROUP = "country"
global const ARMY_GROUP = "army"
const RANK_GROUP = "rank"
const COMMON_PARAMS_GROUP = "common"
const BASE_GROUP = "base"
const EXTENDED_GROUP = "extended"


web_rpc.register_handler("exportUnitInfo", exportUnitInfo)

class UnitInfoExporter
{
  static EXPORT_TIME_OUT = 20000
  static activeUnitInfoExporters = []
  lastActiveTime = -1

  path = "export"
  langsList = null

  langBeforeExport = ""
  curLang = ""

  debugLog = ::dlog // warning disable: -forbidden-function
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

    ::get_main_gui_scene().performDelayed(this, nextLangExport)  //delay to show exporter logs
  }

  function _tostring()
  {
    return format("Exporter(%s, '%s')", ::toString(langsList), path)
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

    debugLog($"Exporter: gen all units info to {getFullPath()}")
    ::get_main_gui_scene().performDelayed(this, startExport) //delay to show exporter logs
  }

  function getFullPath()
  {
    local relPath = ::u.isEmpty(path) ? "" : (path + "/")
    return ::format("%sunitInfo%s.blk", relPath, curLang)
  }

  function startExport()
  {
    fullBlk = ::DataBlock()
    exportUnitType(fullBlk)
    exportCountry(fullBlk)
    exportRank(fullBlk)
    exportCommonParams(fullBlk)

    fullBlk[BASE_GROUP] = ::DataBlock()
    fullBlk[EXTENDED_GROUP] = ::DataBlock()

    unitsList = ::u.values(::all_units)

    updateActive()

    processUnits()
  }

  function finishExport(fBlk)
  {
    fBlk.saveToTextFile(getFullPath())
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

    foreach(country in ::shopCountriesList)
      fBlk[COUNTRY_GROUP][country] = ::loc(country)
  }

  function exportRank(fBlk)
  {
    fBlk[RANK_GROUP] = ::DataBlock()
    fBlk[RANK_GROUP].header = ::loc("shop/age")
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

    if (!curUnit.modificators)
    {
      if (curUnit.isTank())
        return check_unit_mods_update(curUnit)
    }

    local groupId = curUnit.showOnlyWhenBought? EXTENDED_GROUP : BASE_GROUP

    local armyId = curUnit.unitType.armyId

    local countryId = curUnit.shopCountry

    if(countryId == null || countryId == "")
      return true;

    local rankId = curUnit.rank.tostring()

    local unitBlk = ::DataBlock()

    foreach(infoType in ::g_unit_info_type.types)
    {
      local blk = infoType.exportToDataBlock(curUnit)
      if(blk?.hide ?? false)
        continue
      unitBlk[infoType.id] = blk
    }

    local targetBlk = fBlk.addBlock(groupId).addBlock(armyId).addBlock(countryId).addBlock(rankId)
    targetBlk[curUnit.name] = unitBlk
    return true
  }
}