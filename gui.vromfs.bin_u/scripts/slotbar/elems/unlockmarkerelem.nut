local elemModelType = require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")
local { topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")

elemModelType.addTypes({
  UNLOCK_MARKER = {
    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventShopWndSwitched = @(p) notify([])
  }
})

elemViewType.addTypes({
  COUNTRY_UNLOCK_MARKER = {
    model = elemModelType.UNLOCK_MARKER
    updateView = @(obj, _) obj.show(topMenuShopActive.value)
  }
})
