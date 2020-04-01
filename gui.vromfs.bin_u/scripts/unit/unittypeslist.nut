local enums = require("sqStdlibs/helpers/enums.nut")

const BULLETS_SETS_QUANTITY_SHORT = 4

enum UNIT_TYPE_ORDER
{
  AIRCRAFT
  TANK
  SHIP
  HELICOPTER
  INVALID
}

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
    sortOrder = UNIT_TYPE_ORDER.INVALID
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
}

unitTypes.addType <- function(list)
{
  enums.addTypes(this, list,
    function()
    {
      if (esUnitType != ::ES_UNIT_TYPE_INVALID)
      {
        bit = 1 << esUnitType
        bitCrewType = 1 << crewUnitType
      }
      lowerName = name.tolower()
    },
    "typeName"
  )

  unitTypes.types.sort(@(a, b) a.sortOrder <=> b.sortOrder)
}

unitTypes.addType({
  INVALID = {
    name = "Invalid"
    armyId = ""
    esUnitType = ::ES_UNIT_TYPE_INVALID
    sortOrder = UNIT_TYPE_ORDER.INVALID
    haveAnyUnitInCountry = @() false
  }

  AIRCRAFT = {
    name = "Aircraft"
    tag = "air"
    armyId = "aviation"
    esUnitType = ::ES_UNIT_TYPE_AIRCRAFT
    sortOrder = UNIT_TYPE_ORDER.AIRCRAFT
    fontIcon = ::loc("icon/unittype/aircraft")
    testFlightIcon = "#ui/gameuiskin#slot_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_air"
    missionSettingsAvailabilityFlag = "isAirplanesAllowed"
    isUsedInKillStreaks = true
    crewUnitType = ::CUT_AIRCRAFT
    hasAiGunners = true
    isAvailable = @() true
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable())
        return false
      if (!country)
        return true
      local countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return ::has_feature(countryShort + "AircraftsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
    canShowProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisAircraft")
    canShowVisualEffectInProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisVisualEffect")
  }

  TANK = {
    name = "Tank"
    tag = "tank"
    armyId = "army"
    esUnitType = ::ES_UNIT_TYPE_TANK
    sortOrder = UNIT_TYPE_ORDER.TANK
    fontIcon = ::loc("icon/unittype/tank")
    testFlightIcon = "#ui/gameuiskin#slot_testdrive.svg"
    testFlightName = "TestDrive"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_tank"
    missionSettingsAvailabilityFlag = "isTanksAllowed"
    crewUnitType = ::CUT_TANK
    isAvailable = function() { return ::has_feature("Tanks") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !::check_tanks_available(true))
        return false
      if (!country)
        return true
      local countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return ::has_feature(countryShort + "TanksInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["mobility", "protection", "firepower"]
    isSkinAutoSelectAvailable = @() ::has_feature("SkinAutoSelect")
    canSpendGold = @() isAvailable() && ::has_feature("SpendGoldForTanks")
    canShowProtectionAnalysis = @() true
    canShowVisualEffectInProtectionAnalysis = @() false
  }

  SHIP = {
    name = "Ship"
    tag = "ship"
    armyId = "fleet"
    esUnitType = ::ES_UNIT_TYPE_SHIP
    sortOrder = UNIT_TYPE_ORDER.SHIP
    fontIcon = ::loc("icon/unittype/ship")
    testFlightIcon = "#ui/gameuiskin#slot_test_out_to_sea.svg"
    testFlightName = "TestSail"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_ship"
    missionSettingsAvailabilityFlag = "isShipsAllowed"
    crewUnitType = ::CUT_SHIP
    hasAiGunners = true
    isAvailable = function() { return ::has_feature("Ships") }
    isVisibleInShop = function() { return isAvailable() && ::has_feature("ShipsVisibleInShop") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !::has_feature("ShipsFirstChoice"))
        return false
      if (!country)
        return true
      local countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return ::has_feature(countryShort + "ShipsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["seakeeping", "unsinkability", "firepower"]
    canSpendGold = @() isAvailable() && ::has_feature("SpendGoldForShips")
    canShowProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisShip")
    canShowVisualEffectInProtectionAnalysis = @() false
    bulletSetsQuantity = ::BULLETS_SETS_QUANTITY
  }

  HELICOPTER = {
    name = "Helicopter"
    tag = "helicopter"
    armyId = "helicopters"
    esUnitType = ::ES_UNIT_TYPE_HELICOPTER
    sortOrder = UNIT_TYPE_ORDER.HELICOPTER
    fontIcon = ::loc("icon/unittype/helicopter")
    testFlightIcon = "#ui/gameuiskin#slot_heli_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_helicopter"
    missionSettingsAvailabilityFlag = "isHelicoptersAllowed"
    isUsedInKillStreaks = true
    crewUnitType = ::CUT_AIRCRAFT
    isAvailable = @() true
    isVisibleInShop = function() { return isAvailable() }
    isAvailableForFirstChoice = @(country = null) false
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
    canShowProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisAircraft")
    canShowVisualEffectInProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisVisualEffect")
  }
})

return unitTypes