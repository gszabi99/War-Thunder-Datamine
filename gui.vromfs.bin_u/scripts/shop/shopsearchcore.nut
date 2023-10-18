//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let regexp2 = require("regexp2")
let { utf8ToLower } = require("%sqstd/string.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

let reUnitLocNameSeparators = regexp2(@"[ \-_/.()" + nbsp + "]")
let translit = { cyr = "авекмнорстх", lat = "abekmhopctx" }
let searchTokensCache = {}

local function comparePrep(text) {
  text = utf8(utf8ToLower(text)).strtr(translit.cyr, translit.lat)
  return reUnitLocNameSeparators.replace("", text)
}

let function cacheUnitSearchTokens(unit) {
  let tokens = []
  u.appendOnce(comparePrep(getUnitName(unit.name, true)),  tokens)
  u.appendOnce(comparePrep(getUnitName(unit.name, false)), tokens)
  searchTokensCache[unit] <- tokens
}

let function clearCache() {
  searchTokensCache.clear()
}

let function rebuildCache() {
  if (!::g_login.isLoggedIn())
    return

  clearCache()
  foreach (unit in getAllUnits())
    cacheUnitSearchTokens(unit)
}

let function tokensMatch(tokens, searchStr) {
  foreach (t in tokens)
    if (t.indexof(searchStr) != null)
      return true
  return false
}

let function findUnitsByLocName(searchStrRaw, needIncludeHidden = false, needIncludeNotInShop = false) {
  if (!searchTokensCache.len())
    rebuildCache() // hack, restores cache after scripts reload.

  let searchStr = comparePrep(searchStrRaw)
  if (searchStr == "")
    return []
  return searchTokensCache.filter(@(tokens, unit)
    ((::is_dev_version && needIncludeNotInShop) || unit.isInShop)
      && ((::is_dev_version && needIncludeHidden) || unit.isVisibleInShop())
      && (tokensMatch(tokens, searchStr) || unit.name.contains(searchStrRaw))
    ).keys()
}

add_event_listener("GameLocalizationChanged", @(_p) rebuildCache(),
  null, ::g_listener_priority.CONFIG_VALIDATION)

add_event_listener("SignOut", @(_p) clearCache(),
  null, ::g_listener_priority.DEFAULT)


return {
  findUnitsByLocName = findUnitsByLocName
  cacheUnitSearchTokens = cacheUnitSearchTokens
}