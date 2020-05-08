local enums = require("sqStdlibs/helpers/enums.nut")

const BULLETS_SETS_QUANTITY_SHORT = 4

local crewUnitTypeConfig = {
  [::CUT_INVALID] = {
    crewTag = ""
  },
  [::CUT_AIRCRAFT] = {
    crewTag = "air"
  },
  [::CUT_TANK] = {
    crewTag = "tank"
  },
  [::CUT_SHIP] = {
    crewTag = "ship"
  }
}

local unitTypes = {
  template = {
    typeName = "" //filled automatically by typeName
    name = ""
    lowerName = "" //filled automatically by name.tolower()
    tag = ""
    armyId = ""
    esUnitType = ::ES_UNIT_TYPE_INVALID
    bit = 0      //unitType bit for it mask. filled by esUnitType  (bit = 1 << esUnitType)
    bitCrewType = 0 //crewUnitType bit for it mask
    uiSkin = "!#ui/unitskin#"
    uiClassSkin = "#ui/gameuiskin#"
    fontIcon = ""
    testFlightIcon = ""
    testFlightName = ""
    canChangeViewType = false
    hudTypeCode = ::HUD_TYPE_UNKNOWN
    missionSettingsAvailabilityFlag = ""
    isUsedInKillStreaks = false

    firstChosenTypeUnlockName = null
    crewUnitType = ::CUT_INVALID
    hasAiGunners = false

    isAvailable = function() { return false }
    isVisibleInShop = function() { return isAvailable() }
    isAvailableForFirstChoice = function(country = null) { return isAvailable() }
    isFirstChosen = function()
      { return firstChosenTypeUnlockName != null && ::is_unlocked(-1, firstChosenTypeUnlockName) }
    getTestFlightText = function() { return ::loc("mainmenu/btn" + testFlightName ) }
    getTestFlightUnavailableText = function() { return ::loc("mainmenu/cant" + testFlightName ) }
    getArmyLocName = function() { return ::loc("mainmenu/" + armyId, "") }
    getCrewArmyLocName = @() ::loc("unit_type/" + (crewUnitTypeConfig?[crewUnitType]?.crewTag ?? ""))
    getCrewTag = @() crewUnitTypeConfig?[crewUnitType]?.crewTag ?? ""
    getLocName = function() { return ::loc(::format("unit_type/%s", tag), "") }
    canUseSeveralBulletsForGun = false
    modClassOrder = []
    isSkinAutoSelectAvailable = @() false
    canSpendGold = @() isAvailable()
    canShowProtectionAnalysis = @() false
    canShowVisualEffectInProtectionAnalysis = @() false
    haveAnyUnitInCountry = @(countryName) ::isCountryHaveUnitType(countryName, esUnitType)
    isAvailableByMissionSettings = function(misBlk, useKillStreaks = null)
    {
      if (useKillStreaks == null)
        useKillStreaks = misBlk?.useKillStreaks ?? false
      return (misBlk?[missionSettingsAvailabilityFlag] ?? false) && (!isUsedInKillStreaks || !useKillStreaks)
    }
    getMissionAllowedCraftsClassName = @() name.tolower()

    bulletSetsQuantity = BULLETS_SETS_QUANTITY_SHORT
  }

  types = []
  cache = {
    byName = {}
    byNameNoCase = {}
    byEsUnitType = {}
    byArmyId = {}
    byTag = {}
    byBit = {}
  }

  function getByEsUnitType(esUnitType)
  {
    return enums.getCachedType("esUnitType", esUnitType, cache.byEsUnitType, this, INVALID)
  }

  function getArrayBybitMask(bitMask)
  {
    local typesArray = []
    foreach (t in types)
    {
      if ((t.bit & bitMask) != 0)
        typesArray.append(t)
    }
    return typesArray
  }

  function getByBit(bit)
  {
    return enums.getCachedType("bit", bit, cache.byBit, this, INVALID)
  }

  function getByName(typeName, caseSensitive = true)
  {
    local cacheTbl = caseSensitive ? cache.byName : cache.byNameNoCase
    return enums.getCachedType("name", typeName, cacheTbl, this, INVALID, caseSensitive)
  }

  function getByArmyId(armyId)
  {
    return enums.getCachedType("armyId", armyId, cache.byArmyId, this, INVALID)
  }

  function getByTag(tag)
  {
    return enums.getCachedType("tag", tag, cache.byTag, this, INVALID)
  }

  function getByUnitName(unitId)
  {
    local unit = ::getAircraftByName(unitId)
    return unit ? unit.unitType : INVALID
  }

  function getTypeMaskByTagsString(listStr, separator = "; ", bitMaskName = "bit")
  {
    local res = 0
    local list = ::split(listStr, separator)
    foreach(tag in list)
      res = res | getByTag(tag)[bitMaskName]
    return res
  }

  function getEsUnitTypeMaskByCrewUnitTypeMask(crewUnitTypeMask)
  {
    local res = 0
    foreach(t in types)
      if (crewUnitTypeMask & (1 << t.crewUnitType))
        res = res | t.esUnitType
    return res
  }

  function addTypes(list)
  {
    //This block needed to transform array to table,
    //with sortorder key, because:
    //1) Too many calls such as unitType.AIRCRAFT, i.e. directly to table;
    //2) To keep setted order, because table don't have order
    local sortOrder = 0
    local typesTable = {}
    list.each(function(t) {
      t.sortOrder <- sortOrder++
      typesTable[t.name.toupper()] <- t
    })

    enums.addTypes(this, typesTable,
      function()
      {
        if (esUnitType != ::ES_UNIT_TYPE_INVALID)
        {
          bit = 1 << esUnitType
          bitCrewType = 1 << crewUnitType
        }
        lowerName = name.tolower()
      },
      "typeName",
      "unitTypesList"
    )

    this.types.sort(@(a, b) a.sortOrder <=> b.sortOrder)
  }
}

return unitTypes