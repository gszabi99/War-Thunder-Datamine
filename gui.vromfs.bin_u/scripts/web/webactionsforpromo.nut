local { getPollIdByFullUrl, invalidateTokensCache } = require("scripts/web/webpoll.nut")
local { validateLink, openUrl } = require("scripts/onlineShop/url.nut")
local { addPromoAction } = require("scripts/promo/promoActions.nut")
local { addPromoButtonConfig } = require("scripts/promo/promoButtonsConfig.nut")

local function openLinkWithSource(params = [], source = "promo_open_link") {
  local link = ""
  local forceBrowser = false
  if (::u.isString(params))
    link = params
  else if (::u.isArray(params) && params.len() > 0)
  {
    link = params[0]
    forceBrowser = params?[1] ?? false
  }

  local processedLink = validateLink(link)
  if (processedLink == null)
    return
  openUrl(processedLink, forceBrowser, false, source)
}

addPromoAction("url", function(handler, params, obj) {
  local pollId = getPollIdByFullUrl(params?[0] ?? "")
  if (pollId != null)
    invalidateTokensCache(pollId.tointeger())
  return openLinkWithSource(params)
})

addPromoButtonConfig({
  promoButtonId = "web_poll"
  collapsedIcon = ::loc("icon/web_poll")
})

return {
  openLinkWithSource
}

