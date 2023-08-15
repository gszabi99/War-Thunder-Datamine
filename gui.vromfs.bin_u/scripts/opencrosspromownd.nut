let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")

const CROSSPROMO_LANDING_RU_URL = "http://warthunder.ru/ru/crosspromo"
const CROSSPROMO_LANDING_DEFAULT_URL = "http://warthunder.com/crosspromo"

let supportedComLanguages = ["pl", "de", "cz", "fr", "es", "pt", "ko", "zh"]

let class CrossPromoWnd extends ::gui_handlers.BaseGuiHandlerWT {
  sceneTplName = "%gui/crossPromoWnd.tpl"
  wndType = handlerType.MODAL

  bannerSrc = ""

  function getSceneTplView() {
    return {
      bannerSrc = this.bannerSrc
    }
  }

  function onGoToPromoLanding() {
    let curLoc = ::g_language.getShortName()
    let url = curLoc == "ru" ? CROSSPROMO_LANDING_RU_URL
      : supportedComLanguages.contains(curLoc) ? $"http://warthunder.com/{curLoc}/crosspromo"
      : CROSSPROMO_LANDING_DEFAULT_URL

    openUrl(url)
  }
}

::gui_handlers.CrossPromoWnd <- CrossPromoWnd

return @(bannerSrc) ::handlersManager.loadHandler(CrossPromoWnd, { bannerSrc })