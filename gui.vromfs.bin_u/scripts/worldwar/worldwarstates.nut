from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let { get_game_settings_blk } = require("blkGetters")
let { wwGetConfigurableValues } = require("worldwar")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

const WW_CUR_OPERATION_SAVE_ID = "worldWar/curOperation"
const WW_CUR_OPERATION_COUNTRY_SAVE_ID = "worldWar/curOperationCountry"

let wwstorage = persist("wwstorage", @() { configurableValues = DataBlock() })
local infantryUnits = null
local artilleryUnits = null
local transportUnits = null
local lastPlayedOperationId = null
local lastPlayedOperationCountry = null

function getWwSetting(settingName, defaultValue) {
  return get_game_settings_blk()?.ww_settings[settingName] ?? defaultValue
}

function getWWConfigurableValue(paramPath, defaultValue) {
  return getBlkValueByPath(wwstorage.configurableValues, paramPath, defaultValue)
}

function clearUnitsLists() {
  infantryUnits = null
  artilleryUnits = null
  transportUnits = null
}

function getInfantryUnits() {
  if (infantryUnits == null)
    infantryUnits = getWWConfigurableValue("infantryUnits", infantryUnits)

  return infantryUnits
}

function getArtilleryUnits() {
  if (artilleryUnits == null)
    artilleryUnits = getWWConfigurableValue("artilleryUnits", artilleryUnits)

  return artilleryUnits
}

function getTransportUnits() {
  if (transportUnits == null)
    transportUnits = getWWConfigurableValue("transportUnits", transportUnits)

  return transportUnits
}

function fillConfigurableValues() {
  clearUnitsLists()
  let blk = DataBlock()
  wwGetConfigurableValues(blk)
  wwstorage.configurableValues = blk
  // ----- FIX ME: Weapon masks data should be received from char -----
  if (!("fighterCountAsAssault" in wwstorage.configurableValues)) {
    wwstorage.configurableValues.fighterCountAsAssault = DataBlock()
    wwstorage.configurableValues.fighterCountAsAssault.mgun    = false
    wwstorage.configurableValues.fighterCountAsAssault.cannon  = false
    wwstorage.configurableValues.fighterCountAsAssault.gunner  = false
    wwstorage.configurableValues.fighterCountAsAssault.bomb    = true
    wwstorage.configurableValues.fighterCountAsAssault.torpedo = false
    wwstorage.configurableValues.fighterCountAsAssault.rockets = true
    wwstorage.configurableValues.fighterCountAsAssault.gunpod  = false
  }
  // ------------------------------------------------------------------

  local fighterToAssaultWeaponMask = 0
  let fighterCountAsAssault = wwstorage.configurableValues.fighterCountAsAssault
  for (local i = 0; i < fighterCountAsAssault.paramCount(); i++)
    if (fighterCountAsAssault.getParamValue(i))
      fighterToAssaultWeaponMask = fighterToAssaultWeaponMask | (1 << i)

  wwstorage.configurableValues.fighterToAssaultWeaponMask = fighterToAssaultWeaponMask
}

function updateConfigurableValues() {
  wwGetConfigurableValues(wwstorage.configurableValues)
}

function getArtilleryUnitParamsByBlk(blk) {
  let artillery = getArtilleryUnits()
  for (local i = 0; i < blk.blockCount(); i++) {
    let wwUnitName = blk.getBlock(i).getBlockName()
    if (wwUnitName in artillery)
      return artillery[wwUnitName]
  }

  return null
}

function saveLastPlayed(operationId, country) {
  lastPlayedOperationId = operationId
  lastPlayedOperationCountry = country
  saveLocalByAccount(WW_CUR_OPERATION_SAVE_ID, operationId)
  saveLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, country)
}

function loadLastPlayed() {
  lastPlayedOperationId = loadLocalByAccount(WW_CUR_OPERATION_SAVE_ID)
  if (lastPlayedOperationId)
    lastPlayedOperationCountry = loadLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, profileCountrySq.value)
}

addListenersWithoutEnv({
  WWLoadOperationFirstTime = @(_) fillConfigurableValues()
  WWOperationPreviewLoaded = @(_) fillConfigurableValues()
  LoginComplete            = @(_) loadLastPlayed
  ScriptsReloaded          = @(_) loadLastPlayed
})

return {
  getWwSetting
  getWWConfigurableValue
  fillConfigurableValues
  updateConfigurableValues
  getInfantryUnits
  getArtilleryUnits
  getTransportUnits
  getArtilleryUnitParamsByBlk
  getLastPlayedOperationId = @() lastPlayedOperationId
  getLastPlayedOperationCountry = @() lastPlayedOperationCountry
  saveLastPlayed
}