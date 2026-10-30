import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/web/webpoll.nut" import getPollIdByFullUrl, invalidateTokensCache
from "%scripts/onlineShop/url.nut" import validateLink, openUrl
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%scripts/dagui_library.nut" import *

function openLinkWithSource(params = [], source = "promo_open_link") {
  local link = ""
  local forceBrowser = false
  if (u.isString(params))
    link = params
  else if (u.isArray(params) && params.len() > 0) {
    link = params[0]
    forceBrowser = params?[1] ?? false
  }

  let processedLink = validateLink(link)
  if (processedLink == null)
    return
  openUrl(processedLink, forceBrowser, false, source)
}

addPromoAction("url", function(_handler, params, _obj) {
  let pollId = getPollIdByFullUrl(params?[0] ?? "")
  if (pollId != null)
    invalidateTokensCache(pollId.tointeger())
  return openLinkWithSource(params)
})

addPromoButtonConfig({
  promoButtonId = "web_poll"
  collapsedIconLocKey = "icon/web_poll"
})

return freeze({
  openLinkWithSource
})
