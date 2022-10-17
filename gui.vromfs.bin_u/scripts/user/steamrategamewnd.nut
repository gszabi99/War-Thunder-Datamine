from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { openUrl } = require("%scripts/onlineShop/url.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_handlers.SteamRateGame <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/steamRateGame/steamRateGame"

  getSceneTplView = @() {}
  initScreen = @() null

  onApply = @() openUrl(loc("url/steam/community", {appId = ::steam_get_app_id()} ))
  onEventDestroyEmbeddedBrowser = @(p) goBack()
}

return {
  open = @() ::handlersManager.loadHandler(::gui_handlers.SteamRateGame)
}