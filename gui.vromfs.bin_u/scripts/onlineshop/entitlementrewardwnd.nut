from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getEntitlementView, getEntitlementLayerIcons } = require("%scripts/onlineShop/entitlementView.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.EntitlementRewardWnd <- class extends ::gui_handlers.trophyRewardWnd
{
  wndType = handlerType.MODAL

  entitlementConfig = null

  chestDefaultImg = "every_day_award_trophy_big"

  prepareParams = @() null
  getTitle = @() getEntitlementName(entitlementConfig)
  isRouletteStarted = @() false

  viewParams = null

  function openChest() {
    if (this.opened)
      return false

    this.opened = true
    this.updateWnd()
    return true
  }

  function checkConfigsArray() {
    let unitNames = entitlementConfig?.aircraftGift ?? []
    if (unitNames.len())
      this.unit = ::getAircraftByName(unitNames[0])

    let decalsNames = entitlementConfig?.decalGift ?? []
    let attachablesNames = entitlementConfig?.attachableGift ?? []
    let skinsNames = entitlementConfig?.skinGift ?? []
    local resourceType = ""
    local resource = ""
    if (decalsNames.len())
    {
      resourceType = "decal"
      resource = decalsNames[0]
    }
    else if (attachablesNames.len())
    {
      resourceType = "attachable"
      resource = attachablesNames[0]
    }
    else if (skinsNames.len())
    {
      resourceType = "skin"
      resource = skinsNames[0]
    }

    if (resource != "")
      this.updateResourceData(resource, resourceType)
  }

  function getIconData() {
    if (!this.opened)
      return ""

    return "{0}{1}".subst(
      ::LayersIcon.getIconData($"{chestDefaultImg}_opened"),
      getEntitlementLayerIcons(entitlementConfig)
    )
  }

  function updateRewardText() {
    if (!this.opened)
      return

    let obj = this.scene.findObject("prize_desc_div")
    if (!checkObj(obj))
      return

    let data = getEntitlementView(entitlementConfig, (viewParams ?? {}).__merge({
      header = loc("mainmenu/you_received")
      multiAwardHeader = true
      widthByParentParent = true
    }))

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  checkSkipAnim = @() false
  notifyTrophyVisible = @() null
  updateRewardPostscript = @() null
  updateRewardItem = @() null
}

return {
  showEntitlement = function(entitlementId, params = {}) {
    let config = getEntitlementConfig(entitlementId)
    if (!config)
    {
      logerr($"Entitlement Reward: Could not find entitlement config {entitlementId}")
      return
    }

    ::handlersManager.loadHandler(::gui_handlers.EntitlementRewardWnd, {
      entitlementConfig = config
      viewParams = params
    })
  }
}