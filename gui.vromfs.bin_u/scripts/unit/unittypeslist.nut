from "%scripts/dagui_natives.nut" import is_unlocked
from "%scripts/dagui_library.nut" import *

let { split_by_chars } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { isCountryHaveUnitType } = require("%scripts/shop/shopCountryInfo.nut")
let { dynamic_content } = require("%sqstd/analyzer.nut")

const BULLETS_SETS_QUANTITY_SHORT = 4

let crewUnitTypeConfig = {
  [CUT_INVALID] = {
    crewTag = ""
  },
  [CUT_AIRCRAFT] = {
    crewTag = "air"
  },
  [CUT_TANK] = {
    crewTag = "tank"
  },
  [CUT_SHIP] = {
    crewTag = "ship"
  },
  [CUT_HUMAN] = {
    crewTag = "human"
  }
}

let unitTypes = {
  template = {
    typeName = "" 
    name = ""
    lowerName = "" 
    tag = ""
    armyId = ""
    esUnitType = ES_UNIT_TYPE_INVALID
    bit = 0      
    bitCrewType = 0 
    visualSortOrder = -1
    uiSkin = "!#ui/unitskin#"
    fontIcon = ""
    testFlightIcon = ""
    testFlightName = ""
    bailoutName = "btnLeaveTheTank"
    bailoutQuestion = "questionLeaveTheTank"
    canChangeViewType = false
    hudTypeCode = HUD_TYPE_UNKNOWN
    missionSettingsAvailabilityFlag = ""
    isUsedInKillStreaks = false
    isPresentOnMatching = true
    isWideUnitIco = false

    firstChosenTypeUnlockName = null
    crewUnitType = CUT_INVALID
    hasAiGunners = false

    isAvailable = function() { return false }
    isVisibleInShop = function() { return this.isAvailable() }
    isAvailableForFirstChoice = function(_country = null) { return this.isAvailable() }
    isFirstChosen = function() { return this.firstChosenTypeUnlockName != null && is_unlocked(-1, this.firstChosenTypeUnlockName) }
    getTestFlightText = function() { return loc($"mainmenu/btn{this.testFlightName}") }
    getTestFlightUnavailableText = function() { return loc($"mainmenu/cant{this.testFlightName}") }
    getBailoutButtonText = @() loc($"flightmenu/{this.bailoutName}")
    getBailoutQuestionText = @() loc($"flightmenu/{this.bailoutQuestion}")
    getArmyLocId = @() $"mainmenu/{this.armyId}"
    getArmyLocName = @() loc(this.getArmyLocId(), "")
    getCrewArmyLocName = @() loc("".concat("unit_type/", (crewUnitTypeConfig?[this.crewUnitType]?.crewTag ?? "")))
    getCrewTag = @() crewUnitTypeConfig?[this.crewUnitType]?.crewTag ?? ""
    getLocName = @() loc($"unit_type/{this.tag}", "")
    canUseSeveralBulletsForGun = false
    modClassOrder = []
    isSkinAutoSelectAvailable = @() false
    canSpendGold = @() this.isAvailable()
    canShowProtectionAnalysis = @() false
    canShowVisualEffectInProtectionAnalysis = @() false
    haveAnyUnitInCountry = @(countryName) isCountryHaveUnitType(countryName, this.esUnitType)
    isAvailableByMissionSettings = function(misBlk, useKillStreaks = null) {
      if (useKillStreaks == null)
        useKillStreaks = misBlk?.useKillStreaks ?? false
      return (misBlk?[this.missionSettingsAvailabilityFlag] ?? false) && (!this.isUsedInKillStreaks || !useKillStreaks)
    }
    getMissionAllowedCraftsClassName = @() this.name.tolower()
    getMatchingUnitType = @() this.esUnitType

    bulletSetsQuantity = BULLETS_SETS_QUANTITY_SHORT
    wheelmenuAxis = []
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

  function getByEsUnitType(esUnitType) {
    return enums.getCachedType("esUnitType", esUnitType, this.cache.byEsUnitType, this, this.INVALID)
  }

  function getArrayBybitMask(bitMask) {
    let typesArray = []
    foreach (t in this.types) {
      if ((t.bit & bitMask) != 0)
        typesArray.append(t)
    }
    return typesArray
  }

  function getByBit(bit) {
    return enums.getCachedType("bit", bit, this.cache.byBit, this, this.INVALID)
  }

  function getByName(typeName, caseSensitive = true) {
    let cacheTbl = caseSensitive ? this.cache.byName : this.cache.byNameNoCase
    return enums.getCachedType("name", typeName, cacheTbl, this, this.INVALID, caseSensitive)
  }

  function getByArmyId(armyId) {
    return enums.getCachedType("armyId", armyId, this.cache.byArmyId, this, this.INVALID)
  }

  function getByTag(tag) {
    return enums.getCachedType("tag", tag, this.cache.byTag, this, this.INVALID)
  }

  function getByUnitName(unitId) {
    let unit = getAircraftByName(unitId)
    return unit ? unit.unitType : this.INVALID
  }

  function getTypeMaskByTagsString(listStr, separator = "; ", bitMaskName = "bit") {
    local res = 0
    let list = split_by_chars(listStr, separator)
    foreach (tag in list)
      res = res | this.getByTag(tag)[bitMaskName]
    return res
  }

  function getEsUnitTypeMaskByCrewUnitTypeMask(crewUnitTypeMask) {
    local res = 0
    foreach (t in this.types)
      if (crewUnitTypeMask & (1 << t.crewUnitType))
        res = res | t.esUnitType
    return res
  }

  function addTypes(list) {
    
    
    
    
    local sortOrder = 0
    let typesTable = {}
    list.each(function(t) {
      t.sortOrder <- sortOrder++
      typesTable[t.name.toupper()] <- t
    })

    enums.addTypes(this, typesTable,
      function() {
        if (this.esUnitType != ES_UNIT_TYPE_INVALID) {
          this.bit = 1 << this.esUnitType
          this.bitCrewType = 1 << this.crewUnitType
        }
        this.lowerName = this.name.tolower()
      },
      "typeName",
      "unitTypesList"
    )

    this.types.sort(@(a, b) a.sortOrder <=> b.sortOrder)
  }
}

return dynamic_content(unitTypes)