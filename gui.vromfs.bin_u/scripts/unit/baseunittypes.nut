from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

enum VISUAL_SORT_ORDER {
  INVALID
  TANK
  HELICOPTER
  AIRCRAFT
  SHIP
  BOAT
}

return {
  INVALID = {
    name = "Invalid"
    armyId = ""
    esUnitType = ES_UNIT_TYPE_INVALID
    visualSortOrder = VISUAL_SORT_ORDER.INVALID
    haveAnyUnitInCountry = @() false
  }

  AIRCRAFT = {
    name = "Aircraft"
    tag = "air"
    armyId = "aviation"
    esUnitType = ES_UNIT_TYPE_AIRCRAFT
    visualSortOrder = VISUAL_SORT_ORDER.AIRCRAFT
    fontIcon = loc("icon/unittype/aircraft")
    testFlightIcon = "#ui/gameuiskin#slot_testflight.svg"
    testFlightName = "TestFlight"
    bailoutName = "btnBailout"
    bailoutQuestion = "questionBailout"
    hudTypeCode = HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_air"
    missionSettingsAvailabilityFlag = "isAirplanesAllowed"
    isUsedInKillStreaks = true
    crewUnitType = CUT_AIRCRAFT
    hasAiGunners = true
    isAvailable = @() true
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable())
        return false
      if (!country)
        return true
      let countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return hasFeature(countryShort + "AircraftsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
    canShowProtectionAnalysis = @() hasFeature("DmViewerProtectionAnalysisAircraft")
    canShowVisualEffectInProtectionAnalysis = @() hasFeature("DmViewerProtectionAnalysisVisualEffect")
    wheelmenuAxis = [ "wheelmenu_x", "wheelmenu_y" ]
  }

  TANK = {
    name = "Tank"
    tag = "tank"
    armyId = "army"
    esUnitType = ES_UNIT_TYPE_TANK
    visualSortOrder = VISUAL_SORT_ORDER.TANK
    fontIcon = loc("icon/unittype/tank")
    testFlightIcon = "#ui/gameuiskin#slot_testdrive.svg"
    testFlightName = "TestDrive"
    hudTypeCode = HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_tank"
    missionSettingsAvailabilityFlag = "isTanksAllowed"
    crewUnitType = CUT_TANK
    isAvailable = function() { return hasFeature("Tanks") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !::check_tanks_available(true))
        return false
      if (!country)
        return true
      let countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return hasFeature(countryShort + "TanksInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["mobility", "protection", "firepower"]
    isSkinAutoSelectAvailable = @() hasFeature("SkinAutoSelect")
    canSpendGold = @() isAvailable() && hasFeature("SpendGoldForTanks")
    canShowProtectionAnalysis = @() true
    canShowVisualEffectInProtectionAnalysis = @() false
    wheelmenuAxis = [ "gm_wheelmenu_x", "gm_wheelmenu_y" ]
  }

  SHIP = {
    name = "Ship"
    tag = "ship"
    armyId = "ships"
    esUnitType = ES_UNIT_TYPE_SHIP
    visualSortOrder = VISUAL_SORT_ORDER.SHIP
    fontIcon = loc("icon/unittype/ship")
    testFlightIcon = "#ui/gameuiskin#slot_test_out_to_sea.svg"
    testFlightName = "TestSail"
    hudTypeCode = HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_ship_without_boat"
    missionSettingsAvailabilityFlag = "isShipsAllowed"
    crewUnitType = CUT_SHIP
    hasAiGunners = true
    isAvailable = function() { return hasFeature("Ships") }
    isVisibleInShop = function() { return isAvailable() && hasFeature("ShipsVisibleInShop") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !hasFeature("ShipsFirstChoice"))
        return false
      if (!country)
        return true
      let countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return hasFeature(countryShort + "ShipsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["seakeeping", "unsinkability", "firepower"]
    canSpendGold = @() isAvailable() && hasFeature("SpendGoldForShips")
    canShowProtectionAnalysis = @() hasFeature("DmViewerProtectionAnalysisShip")
    canShowVisualEffectInProtectionAnalysis = @() false
    bulletSetsQuantity = BULLETS_SETS_QUANTITY
    wheelmenuAxis = [ "ship_wheelmenu_x", "ship_wheelmenu_y" ]
  }

  HELICOPTER = {
    name = "Helicopter"
    tag = "helicopter"
    armyId = "helicopters"
    esUnitType = ES_UNIT_TYPE_HELICOPTER
    visualSortOrder = VISUAL_SORT_ORDER.HELICOPTER
    fontIcon = loc("icon/unittype/helicopter")
    testFlightIcon = "#ui/gameuiskin#slot_heli_testflight.svg"
    testFlightName = "TestFlight"
    bailoutName = "btnBailoutHelicopter"
    bailoutQuestion = "questionBailoutHelicopter"
    hudTypeCode = HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_helicopter"
    missionSettingsAvailabilityFlag = "isHelicoptersAllowed"
    isUsedInKillStreaks = true
    crewUnitType = CUT_AIRCRAFT
    isAvailable = @() true
    isVisibleInShop = function() { return isAvailable() }
    isAvailableForFirstChoice = @(_country = null) false
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
    canShowProtectionAnalysis = @() hasFeature("DmViewerProtectionAnalysisAircraft")
    canShowVisualEffectInProtectionAnalysis = @() hasFeature("DmViewerProtectionAnalysisVisualEffect")
    wheelmenuAxis = [ "helicopter_wheelmenu_x", "helicopter_wheelmenu_y" ]
  }

  BOAT = {
    name = "Boat"
    tag = "boat"
    armyId = "boats"
    esUnitType = ES_UNIT_TYPE_BOAT
    visualSortOrder = VISUAL_SORT_ORDER.BOAT
    fontIcon = loc("icon/unittype/boat")
    testFlightIcon = "#ui/gameuiskin#slot_test_out_to_sea_boat.svg"
    testFlightName = "TestSail"
    hudTypeCode = HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_ship"
    missionSettingsAvailabilityFlag = "isShipsAllowed"
    isPresentOnMatching = false
    crewUnitType = CUT_SHIP
    hasAiGunners = true
    isAvailable = function() { return hasFeature("Ships") }
    isVisibleInShop = function() { return isAvailable() && hasFeature("ShipsVisibleInShop") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !hasFeature("BoatsFirstChoice"))
        return false
      if (!country)
        return true
      let countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return hasFeature(countryShort + "BoatsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["seakeeping", "unsinkability", "firepower"]
    canSpendGold = @() isAvailable() && hasFeature("SpendGoldForShips")
    canShowProtectionAnalysis = @() hasFeature("DmViewerProtectionAnalysisShip")
    canShowVisualEffectInProtectionAnalysis = @() false
    bulletSetsQuantity = BULLETS_SETS_QUANTITY
    wheelmenuAxis = [ "ship_wheelmenu_x", "ship_wheelmenu_y" ]
  }
}