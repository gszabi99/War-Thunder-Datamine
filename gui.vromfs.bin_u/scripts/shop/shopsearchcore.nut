from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitName, reUnitLocNameSeparators } = require("%scripts/unit/unitInfo.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

let translit = { cyr = "авекмнорстх", lat = "abekmhopctx" }
let searchTokensCache = {}
local lastQuery = ""
local lastQueryToken = ""

function comparePrep(text) {
  text = utf8(utf8ToLower(text)).strtr(translit.cyr, translit.lat)
  return reUnitLocNameSeparators.replace("", text)
}

function cacheUnitSearchTokens(unit) {
  let tokens = []
  appendOnce(comparePrep(getUnitName(unit.name, true)),  tokens)
  appendOnce(comparePrep(getUnitName(unit.name, false)), tokens)
  searchTokensCache[unit] <- tokens
}

function clearCache() {
  searchTokensCache.clear()
}

function rebuildCache() {
  if (!isLoggedIn.get())
    return

  clearCache()
  foreach (unit in getAllUnits())
    cacheUnitSearchTokens(unit)
}

function isTokensMatch(tokens, searchToken) {
  foreach (t in tokens)
    if (t.contains(searchToken))
      return true
  return false
}

function getSearchTokenByQuery(searchStr) {
  if (lastQuery != searchStr) {
    lastQuery = searchStr
    lastQueryToken = comparePrep(searchStr)
  }
  return lastQueryToken
}

function findUnitsByLocName(searchStr, needIncludeHidden = false, needIncludeNotInShop = false) {
  if (!searchTokensCache.len())
    rebuildCache() 

  let searchToken = getSearchTokenByQuery(searchStr)
  if (searchToken == "")
    return []
  return searchTokensCache.filter(@(tokens, unit)
    ((is_dev_version() && needIncludeNotInShop) || unit.isInShop)
      && ((is_dev_version() && needIncludeHidden) || unit.isVisibleInShop())
      && (isTokensMatch(tokens, searchToken) || unit.name == searchStr)
    ).keys()
}

function isUnitLocNameMatchSearchStr(unit, searchStr) {
  if (!searchTokensCache.len())
    rebuildCache() 

  let searchToken = getSearchTokenByQuery(searchStr)
  if (searchToken == "")
    return false
  let tokens = searchTokensCache?[unit] ?? []
  return isTokensMatch(tokens, searchToken) || unit.name == searchStr
}

add_event_listener("GameLocalizationChanged", @(_p) rebuildCache(),
  null, g_listener_priority.CONFIG_VALIDATION)

add_event_listener("SignOut", @(_p) clearCache(),
  null, g_listener_priority.DEFAULT)

return {
  findUnitsByLocName
  isUnitLocNameMatchSearchStr
  cacheUnitSearchTokens
}