local elemModelType = require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = require("sqDagui/elemUpdater/elemViewType.nut")
local { topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")
local { hasMarker, hasMarkerByCountry,
  hasMarkerByArmyId } = require("scripts/unlocks/unlockMarkers.nut")
local { getShopDiffCode } = require("scripts/shop/shopDifficulty.nut")

elemModelType.addTypes({
  UNLOCK_MARKER = {
    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventShopWndSwitched = @(p) notify([])
    onEventUnlockMarkersCacheInvalidate = @(p) notify([])
    onEventShopDiffCodeChanged = @(p) notify([])
    onEventCurrentGameModeIdChanged = @(p) notify([])
  }
})

elemViewType.addTypes({
  UNLOCK_MARKER = {
    model = elemModelType.UNLOCK_MARKER

    updateView = function(obj, _) {
      local isVisible = hasMarker(getShopDiffCode())
      obj.show(isVisible)
    }
  }

  COUNTRY_UNLOCK_MARKER = {
    model = elemModelType.UNLOCK_MARKER

    updateView = function(obj, _) {
      local isVisible = topMenuShopActive.value
        && hasMarkerByCountry(obj.countryId, getShopDiffCode())
      obj.show(isVisible)
    }
  }

  SHOP_PAGES_UNLOCK_MARKER = {
    model = elemModelType.UNLOCK_MARKER

    updateView = function(obj, params) {
      local objConfig = ::split(obj.id, ";")
      local isVisible = topMenuShopActive.value
        && hasMarkerByCountry(objConfig?[0], getShopDiffCode())
        && hasMarkerByArmyId(objConfig?[1], getShopDiffCode())

      obj.show(isVisible)
    }
  }
})
