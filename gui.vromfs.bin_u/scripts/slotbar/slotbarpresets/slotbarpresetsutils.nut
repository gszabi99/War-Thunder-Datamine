from "%sqStdLibs/helpers/u.nut" import mapAdvanced
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%sqstd/datablock.nut" import convertBlk
from "string" import format
from "%scripts/dagui_library.nut" import *

let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { calculateBR } = require("%scripts/slotbar/slotbarPresets/calcRanks.nut")
let { getGameModeById, getCurrentGameModeId, getGameModeByUnitType } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrafts } = require("%scripts/battleRating.nut")
let { getMyCrewUnitsState, getPresetsListFromSlotbar } = require("%scripts/slotbar/slotbarPresetsHelpers.nut")
let { getCurrentPresetIdx } = require("%scripts/slotbar/slotbarPresetsState.nut")

local initSettings = [
  { id = "enable_auto_abbreviation" }
  { id = "modes_abbreviation" }
  { id = "show_modes", depended = true }
  { id = "show_ratings", depended = true }
  { id = "show_titles", depended = true, selected = true }
]

local settings = null

function getPresetsSettings() {
  if (settings != null)
    return settings

  let data = loadLocalAccountSettings("slotbarPresetsSettings")
  settings = data != null ? convertBlk(data).array : initSettings
  return settings
}

function setPresetsSetting(id, value) {
  let val = settings.findvalue(@(v) v.id == id)
  if (val != null && val?.selected != value) {
    val.selected <- value
    saveLocalAccountSettings("slotbarPresetsSettings", settings)
    broadcastEvent("SlotbarPresetSettingsChanged")
  }
}

function getPresetData(country, presetData, ediff) {
  return {
    country
    crafts = getCrafts({
      country
      crewAirs = { [country] = presetData.units }
      brokenAirs = getMyCrewUnitsState(country).brokenAirs
    }, country, ediff)
  }
}

function getCountryPresetsBRs(presetData, gameModeId, country) {
  let gameMode = getGameModeById(gameModeId)
  let event = gameMode?.getEvent()
  if (gameMode == null || event == null)
    return ""

  let data = getPresetData(country, presetData, gameMode.ediff)
  let mrank = calculateBR(data, event)
  return mrank != -1 ? format("%.1f", calcBattleRatingFromRank(mrank)) : loc("leaderboards/notAvailable")
}

function isSettingsSelected(name) {
  return getPresetsSettings().findvalue(@(v) v.id == name)?.selected ?? false
}


function getGameModeIdByUnits(units) {
  if (units.len() == 0)
    return ""

  let unit = getAircraftByName(units[0])
  if (unit == null)
    return ""

  let gameMode = getGameModeByUnitType(unit.unitType.esUnitType)
  return gameMode != null ? gameMode.id : ""
}

function getPresetsDataByCountry(country) {
  let curPresetIdx = getCurrentPresetIdx(country, 0)

  let res = mapAdvanced(getPresetsListFromSlotbar(country),
    function(preset, idx, ...) {
      let { gameModeId = "", enabled, units } = preset

      let gmId = idx == curPresetIdx ? getCurrentGameModeId()
        : gameModeId != "" ? gameModeId
        : getGameModeIdByUnits(units)
      return preset.__merge({
        isEnabled = enabled || idx == curPresetIdx
        gameModeId = gmId
        curPresetIdx
        br = getCountryPresetsBRs(preset, gmId, country)
      })
    })

  return res
}

addListenersWithoutEnv({
  LoginComplete = @(_p) settings = null
})

return {
  getPresetsSettings
  setPresetsSetting
  getCountryPresetsBRs

  isShowModes = @() isSettingsSelected("show_modes")
  isShowTitles = @() isSettingsSelected("show_titles")
  isShowRatings = @() isSettingsSelected("show_ratings")
  isAbbreviateModes = @() isSettingsSelected("modes_abbreviation")
  isAutoAbbreviation = @() isSettingsSelected("enable_auto_abbreviation")

  getPresetsDataByCountry
}
