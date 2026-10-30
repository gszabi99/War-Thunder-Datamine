from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/onlineShop/url.nut" import openUrl
from "%scripts/langUtils/language.nut" import getCurLangShortName

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

let supportedComLanguages = ["en", "ru", "pl", "de", "cz", "fr", "es", "pt", "ko", "zh"]

class CrossPromoWnd (BaseGuiHandlerWT) {
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

register_gui_handler("CrossPromoWnd", CrossPromoWnd)

return @(bannerSrc) handlersManager.loadHandler(CrossPromoWnd, { bannerSrc })