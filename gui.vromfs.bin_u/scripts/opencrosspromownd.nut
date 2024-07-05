let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")

const CROSSPROMO_LANDING_RU_URL = "https://warthunder.com/ru/news/8405"
const CROSSPROMO_LANDING_DEFAULT_URL = "http://warthunder.com/crosspromo"

let supportedComLanguages = ["pl", "de", "cz", "fr", "es", "pt", "ko", "zh"]

let class CrossPromoWnd (gui_handlers.BaseGuiHandlerWT) {
  sceneTplName = "%gui/crossPromoWnd.tpl"
  wndType = handlerType.MODAL

  bannerSrc = ""

  function getSceneTplView() {
    return {
      bannerSrc = this.bannerSrc
    }
  }

  function onGoToPromoLanding() {
    let curLoc = getCurLangShortName()
    let url = curLoc == "ru" ? CROSSPROMO_LANDING_RU_URL
      : supportedComLanguages.contains(curLoc) ? $"http://warthunder.com/{curLoc}/crosspromo"
      : CROSSPROMO_LANDING_DEFAULT_URL

    openUrl(url)
  }
}

gui_handlers.CrossPromoWnd <- CrossPromoWnd

return @(bannerSrc) handlersManager.loadHandler(CrossPromoWnd, { bannerSrc })