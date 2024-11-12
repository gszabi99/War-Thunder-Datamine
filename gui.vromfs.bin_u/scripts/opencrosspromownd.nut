let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")

let supportedComLanguages = ["en", "ru", "pl", "de", "cz", "fr", "es", "pt", "ko", "zh"]

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
    let lang = supportedComLanguages.contains(curLoc) ? curLoc : "en"
    openUrl($"https://warthunder.com/{lang}/news/9197")
  }
}

gui_handlers.CrossPromoWnd <- CrossPromoWnd

return @(bannerSrc) handlersManager.loadHandler(CrossPromoWnd, { bannerSrc })