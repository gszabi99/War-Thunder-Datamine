let enums = require("%sqStdLibs/helpers/enums.nut")
let {regexp} = require("string")
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
  isOnlineShop = false
  urlRegexpList = null //array
  supportedLangs = ["ru", "en", "fr", "de", "es", "pl", "ja", "cs", "pt", "ko", "tr", "zh"] //array of short lang
  langParamName = "skin_lang"

  isCorrespondsToUrl = function(url) {
    if (!this.urlRegexpList)
      return true
    foreach (r in this.urlRegexpList)
      if (r.match(url))
        return true
    return false
  }

  applyCurLang = function(url) {
    let langKey = this.getCurLangKey();
    return langKey ? this.applyLangKey(url, langKey) : url
  }

  getCurLangKey = function() {
    if (!this.supportedLangs)
      return null
    let curLang = ::g_language.getShortName()
    if (::isInArray(curLang, this.supportedLangs))
      return curLang
    return null
  }

  applyLangKey = @(url, langKey)
    $"{url}{url.indexof("?") == null ? "?" : "&"}{this.langParamName}={langKey}"
}

enums.addTypesByGlobalName("g_url_type", {
  UNKNOWN = {
    sortOrder = URL_CHECK_ORDER.UNKNOWN
  }

  ONLINE_SHOP = {
    isOnlineShop = true
    urlRegexpList = [
      regexp(@"^https?:\/\/store\.gaijin\.net" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/online\.gaijin\.ru" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/online\.gaijinent\.com" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/trade\.gaijin\.net" + URL_ANY_ENDING),
      regexp(@"^https?:\/\/inventory-test-01\.gaijin\.lan" + URL_ANY_ENDING),
    ]
  }

  GAIJIN_PASS = {
    langParamName = "lang"
    urlRegexpList = [
      regexp(@"^https?:\/\/login\.gaijin\.net" + URL_ANY_ENDING)
    ]
  }

  WARTHUNDER_RU = {
    urlRegexpList = [
      regexp(@"^https?:\/\/warthunder\.ru" + URL_ANY_ENDING),
    ]
  }

  WARTHUNDER_COM = {
    supportedLangs = ["ru", "en","pl","de","cz","fr","es","tr","pt"] //ru - forward to warthunder.ru
    urlRegexpList = [
      regexp(@"^https?:\/\/warthunder\.com" + URL_ANY_ENDING),
    ]
    applyLangKey = function(url, langKey)
    {
      let keyBeforeLang = ".com/"
      let idx = url.indexof(keyBeforeLang)
      if (idx == null)
        return url + "/" + langKey

      let insertIdx = idx + keyBeforeLang.len()
      local afterLangIdx = url.indexof("/", insertIdx)
      if (afterLangIdx == null || !::isInArray(url.slice(insertIdx, afterLangIdx), this.supportedLangs))
        afterLangIdx = insertIdx
      else
        afterLangIdx++
      return url.slice(0, insertIdx) + langKey + "/" + url.slice(afterLangIdx)
    }
  }
}, null, "typeName")

::g_url_type.types.sort(function(a,b)
{
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder > b.sortOrder ? 1 : -1
  return 0
})

::g_url_type.getByUrl <- function getByUrl(url)
{
  foreach (urlType in this.types)
    if (urlType.isCorrespondsToUrl(url))
      return urlType
  return this.UNKNOWN
}
