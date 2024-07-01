from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%sqDagui/elemUpdater/elemViewType.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")

elemModelType.addTypes({
  UNLOCK_MARKER = {
    init = @() subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)

    onEventShopWndSwitched = @(_p) this.notify([])
  }
})

elemViewType.addTypes({
  COUNTRY_UNLOCK_MARKER = {
    model = elemModelType.UNLOCK_MARKER
    updateView = @(obj, _) obj.show(topMenuShopActive.value)
  }
})
