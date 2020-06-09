local { getEntitlementConfig, getEntitlementName } = require("scripts/onlineShop/entitlements.nut")
local { getEntitlementView, getEntitlementLayerIcons } = require("scripts/onlineShop/entitlementView.nut")

class ::gui_handlers.EntitlementRewardWnd extends ::gui_handlers.trophyRewardWnd
{
  wndType = handlerType.MODAL

  entitlementConfig = null

  chestDefaultImg = "every_day_award_trophy_big"

  prepareParams = @() null
  getTitle = @() getEntitlementName(entitlementConfig)
  isRouletteStarted = @() false

  viewParams = null

  function openChest() {
    if (opened)
      return false

    opened = true
    updateWnd()
    return true
  }

  function checkConfigsArray() {
    local unitNames = entitlementConfig?.aircraftGift ?? []
    if (unitNames.len())
      unit = ::getAircraftByName(unitNames[0])

    local decalsNames = entitlementConfig?.decalGift ?? []
    local skinsNames = entitlementConfig?.skinGift ?? []
    local decoratorType = null
    if (decalsNames.len())
    {
      decoratorType = ::g_decorator_type.DECALS
      decorator = ::g_decorator.getDecorator(decalsNames[0], ::g_decorator_type.DECALS)
    }
    else if (skinsNames.len())
    {
      decoratorType = ::g_decorator_type.SKINS
      decorator = ::g_decorator.getDecorator(skinsNames[0], ::g_decorator_type.SKINS)
    }

    if (!decorator)
      return

    local decorUnit = decoratorType == ::g_decorator_type.SKINS ?
      ::getAircraftByName(::g_unlocks.getPlaneBySkinId(decorator.id)) :
      ::get_player_cur_unit()

    if (decorUnit && decoratorType.isAvailable(decorUnit) && decorator.canUse(decorUnit))
    {
      local freeSlotIdx = decoratorType.getFreeSlotIdx(decorUnit)
      local slotIdx = freeSlotIdx != -1 ? freeSlotIdx
        : (decoratorType.getAvailableSlots(decorUnit) - 1)

      decoratorUnit = decorUnit
      decoratorSlot = slotIdx

      local obj = scene.findObject("btn_use_decorator")
      if (::check_obj(obj))
        obj.setValue(::loc("decorator/use/" + decoratorType.resourceType))
    }
  }

  function getIconData() {
    if (!opened)
      return ""

    return "{0}{1}".subst(
      ::LayersIcon.getIconData($"{chestDefaultImg}_opened"),
      getEntitlementLayerIcons(entitlementConfig)
    )
  }

  function updateRewardText() {
    if (!opened)
      return

    local obj = scene.findObject("prize_desc_div")
    if (!::checkObj(obj))
      return

    local data = getEntitlementView(entitlementConfig, (viewParams ?? {}).__update({
      header = ::loc("mainmenu/you_received")
      multiAwardHeader = true
      widthByParentParent = true
    }))

    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  checkSkipAnim = @() false
  notifyTrophyVisible = @() null
  updateRewardPostscript = @() null
  updateRewardItem = @() null
}

return {
  showEntitlement = function(entitlementId, params = {}) {
    local config = getEntitlementConfig(entitlementId)
    if (!config)
    {
      ::dagor.logerr($"Entitlement Reward: Could not find entitlement config {entitlementId}")
      return
    }

    ::handlersManager.loadHandler(::gui_handlers.EntitlementRewardWnd, {
      entitlementConfig = config
      viewParams = params
    })
  }
}