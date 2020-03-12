local reUnitLocNameSeparators = ::regexp2(@"[ \-_/.()"+::nbsp+"]")
local translit = { cyr = "авекмнорстх", lat = "abekmhopctx" }
local searchTokensCache = {}

local function comparePrep(text)
{
  text = ::utf8(::g_string.utf8ToLower(text)).strtr(translit.cyr, translit.lat)
  return reUnitLocNameSeparators.replace("", text)
}

local function cacheUnitSearchTokens(unit)
{
  local tokens = []
  ::u.appendOnce(comparePrep(::getUnitName(unit.name, true)),  tokens)
  ::u.appendOnce(comparePrep(::getUnitName(unit.name, false)), tokens)
  searchTokensCache[unit] <- tokens
}

local function rebuildCache()
{
  if (!::g_login.isLoggedIn())
    return

  searchTokensCache.clear()
  foreach (unit in ::all_units)
    cacheUnitSearchTokens(unit)
}

local function tokensMatch(tokens, searchStr)
{
  foreach (t in tokens)
    if (t.indexof(searchStr) != null)
      return true
  return false
}

local function findUnitsByLocName(searchStrRaw, needIncludeHidden = false, needIncludeNotInShop = false)
{
  if (!searchTokensCache.len())
    rebuildCache() // hack, restores cache after scripts reload.

  local searchStr = comparePrep(searchStrRaw)
  if (searchStr == "")
    return []
  return ::u.keys(searchTokensCache.filter(@(tokens, unit)
    ((::is_dev_version && needIncludeNotInShop) || unit.isInShop)
      && ((::is_dev_version && needIncludeHidden)    || unit.isVisibleInShop())
      && (tokensMatch(tokens, searchStr) || (::is_dev_version && unit.name == searchStrRaw))
  ))
}

::add_event_listener("GameLocalizationChanged", @(p) rebuildCache(),
  null, ::g_listener_priority.CONFIG_VALIDATION)

return {
  findUnitsByLocName = findUnitsByLocName
  cacheUnitSearchTokens = cacheUnitSearchTokens
}
