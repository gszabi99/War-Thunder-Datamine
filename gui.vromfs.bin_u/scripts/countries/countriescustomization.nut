from "%scripts/dagui_library.nut" import *
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { isChineseVersion } = require("%scripts/langUtils/language.nut")
let { getPlayerCountryCode } = require("%scripts/user/countryUtils.nut")

const CUSTOM_COUNTRIES_DATA_ID = "customCountriesData"
const USE_OPERATOR_FLAGS_IN_BATTLE_ID = "useOperatorFlagsInBattle"

let countryDisplayStyle = {
  DEFAULT = "default"
  ONLY_FLAG = "only_flag"
  ONLY_NAME = "only_name"
}

local countries = null
local customCountriesData = null
local useOperatorFlagsInBattle = null

let contryFlagSubstitute = {
  country_republic_china = {
    isRestricted = @() isChineseVersion() || getPlayerCountryCode() == "CN"
    substitute = "country_china"
  }
  country_usa_modern = {
    isRestricted = @() true
    substitute = "country_usa"
  }
}

function initCustomCountriesData() {
  customCountriesData = {
    flags = {}
    styles = {}
  }
}

function cacheUnitCountries() {
  let cache = {}
  foreach (unit in getAllUnits()) {
    if (!unit.isVisibleInShop())
      continue

    let shopCountry = unit.shopCountry
    if (shopCountry == "")
      continue

    if (shopCountry not in cache)
      cache[shopCountry] <- {}

    let operatorCountry = unit.getOperatorCountry()
    if (shopCountriesList.contains(operatorCountry))
      continue

    cache[shopCountry][operatorCountry] <- (cache?[shopCountry][operatorCountry] ?? false) || unit.isBought()
  }
  return cache
}

function loadCustomCountriesData() {
  let blk = loadLocalAccountSettings(CUSTOM_COUNTRIES_DATA_ID)
  if (blk == null) {
    initCustomCountriesData()
    return
  }

  customCountriesData = convertBlk(blk)
  broadcastEvent("CountryAppearanceChanged")
}

function removeDefaults() {
  customCountriesData.styles = customCountriesData.styles.reduce(function(res, style, country) {
    if (style != "default")
      res[country] <- style
    return res
  }, {})

  customCountriesData.flags = customCountriesData.flags.reduce(function(res, flag, country) {
    if (flag != country)
      res[country] <- flag
    return res
  }, {})
}

function saveCustomCountriesData() {
  removeDefaults()
  saveLocalAccountSettings(CUSTOM_COUNTRIES_DATA_ID, customCountriesData)
}

function getCountryOverride(country) {
  return customCountriesData.flags?[country] ?? country
}

function setCountryOverride(country, name) {
  customCountriesData.flags[country] <- name
  saveCustomCountriesData()
}

function getCountryFlagSubstitute(country) {
  if (country not in contryFlagSubstitute)
    return country

  let restrictionData = contryFlagSubstitute[country]
  return restrictionData.isRestricted() ? restrictionData.substitute : country
}

function getCountryStyle(country) {
  return customCountriesData.styles?[country] ?? "default"
}

function setCountryStyle(country, style) {
  customCountriesData.styles[country] <- style
  saveCustomCountriesData()
}

function getCountries() {
  if (countries == null)
    countries = cacheUnitCountries()
  return countries
}

function resetCountriesStyles() {
  initCustomCountriesData()
  saveLocalAccountSettings(CUSTOM_COUNTRIES_DATA_ID, null)
}

function loadUseOperatorFlagsInBattle() {
  let blk = loadLocalAccountSettings(USE_OPERATOR_FLAGS_IN_BATTLE_ID)
  useOperatorFlagsInBattle = blk?.value ?? true
}

function setUseOperatorFlagsInBattle(value) {
  useOperatorFlagsInBattle = value
  saveLocalAccountSettings(USE_OPERATOR_FLAGS_IN_BATTLE_ID, { value })
}

function getUseOperatorFlagsInBattle() {
  if (useOperatorFlagsInBattle == null)
    loadUseOperatorFlagsInBattle()
  return useOperatorFlagsInBattle
}

let invalidateCountriesCache = @() countries = null

addListenersWithoutEnv({
  UnitBought = @(_) invalidateCountriesCache()
  LoginComplete = @(_) loadCustomCountriesData()
  SignOut = function(_) {
    initCustomCountriesData()
    useOperatorFlagsInBattle = null
    countries = null
  }
})

if (isLoggedIn.get())
  loadCustomCountriesData()
else
  initCustomCountriesData()

return {
  getCountryOverride
  setCountryOverride
  getCountryStyle
  setCountryStyle
  resetCountriesStyles
  countryDisplayStyle
  isCountryOverrided = @(country) getCountryOverride(country) != country
  getCountries
  getUseOperatorFlagsInBattle
  setUseOperatorFlagsInBattle
  getCountryFlagSubstitute
}
