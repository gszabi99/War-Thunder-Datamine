local enums = require("sqStdlibs/helpers/enums.nut")
const URL_ANY_ENDING = @"(\/.*$|\/$|$)"

enum URL_CHECK_ORDER
{
  BY_URL_REGEXP
  UNKNOWN
}

::g_url_type <- {
  types = []
}

::g_url_type.template <- {
  typeName = "" //filled automatically by typeName
  sortOrder = URL_CHECK_ORDER.BY_URL_REGEXP
  needAutoLogin = false
  isOnlineShop = false
  urlRegexpList = null //array
  supportedLangs = null //array of short lang

  isCorrespondsToUrl = function(url)
  {
    if (!urlRegexpList)
      return true
    foreach(r in urlRegexpList)
      if (r.match(url))
        return true
    return false
  }

  applyCurLang = function(url)
  {
    local langKey = getCurLangKey();
    return langKey ? applyLangKey(url, langKey) : url
  }
  getCurLangKey = function()
  {
    if (!supportedLangs)
      return null
    local curLang = ::g_language.getShortName()
    if (::isInArray(curLang, supportedLangs))
      return curLang
    return null
  }
  applyLangKey = function(url, langKey) { return url }
  applySToken = @(url) url
}

enums.addTypesByGlobalName("g_url_type", {
  UNKNOWN = {
    sortOrder = URL_CHECK_ORDER.UNKNOWN
  }

  ONLINE_SHOP = {
    needAutoLogin = true
    isOnlineShop = true
    supportedLangs = ["ru", "en", "fr", "de", "es", "pl", "ja", "cs", "pt", "ko", "tr", "zh"]
    urlRegexpList = [
      regexp(@"^https?:\/\/store\.gaijin\.net" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/online\.gaijin\.ru" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/online\.gaijinent\.com" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/trade\.gaijin\.net" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/inventory-test-01\.gaijin\.lan" + URL_ANY_ENDING),
    ]
    applyLangKey = function(url, langKey)
    {
      url += url.indexof("?") == null ? "?" : "&";
      url += "skin_lang=" + langKey;
      return url
    }
  }

  GAIJIN_PASS = {
    needAutoLogin = true
    supportedLangs = ["ru", "en", "fr", "de", "es", "pl", "ja", "cs", "pt", "ko", "tr", "zh"]
    urlRegexpList = [
      regexp(@"^https?:\/\/login\.gaijin\.net" + URL_ANY_ENDING)
    ]
    applyLangKey = @(url, langKey)
      $"{url}{url.indexof("?") == null ? "?" : "&"}lang={langKey}"

    applySToken = @(url)
      $"{url}{url.indexof("?") == null ? "?" : "&"}st={::get_sso_short_token()?.shortToken ?? ""}"
  }

  WARTHUNDER_RU = {
    needAutoLogin = true
    urlRegexpList = [
      regexp(@"^https?:\/\/warthunder\.ru" + URL_ANY_ENDING),
    ]
  }

  WARTHUNDER_COM = {
    needAutoLogin = true
    supportedLangs = ["ru", "en","pl","de","cz","fr","es","tr","pt"] //ru - forward to warthunder.ru
    urlRegexpList = [
      regexp(@"^https?:\/\/warthunder\.com" + URL_ANY_ENDING),
    ]
    applyLangKey = function(url, langKey)
    {
      local keyBeforeLang = ".com/"
      local idx = url.indexof(keyBeforeLang)
      if (idx == null)
        return url + "/" + langKey

      local insertIdx = idx + keyBeforeLang.len()
      local afterLangIdx = url.indexof("/", insertIdx)
      if (afterLangIdx == null || !::isInArray(url.slice(insertIdx, afterLangIdx), supportedLangs))
        afterLangIdx = insertIdx
      else
        afterLangIdx++
      return url.slice(0, insertIdx) + langKey + "/" + url.slice(afterLangIdx)
    }
  }

  AUTHORIZED_NO_LANG = {
    needAutoLogin = true
    urlRegexpList = [
      regexp(@"^https?:\/\/tss\.warthunder\.com" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/tss\.warthunder\.ru" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/tss-dev\.warthunder\.com" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/tss-dev\.warthunder\.ru" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/live\.warthunder\.com" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/achievements\.gaijin\.net" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/support\.gaijin\.net" + URL_ANY_ENDING),
    ]
  }

}, null, "typeName")

::g_url_type.types.sort(function(a,b)
{
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder > b.sortOrder ? 1 : -1
  return 0
})

g_url_type.getByUrl <- function getByUrl(url)
{
  foreach(urlType in types)
    if (urlType.isCorrespondsToUrl(url))
      return urlType
  return UNKNOWN
}
