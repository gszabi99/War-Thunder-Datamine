from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")

let { getEntitlementConfig, getEntitlementName } = require("%scripts/onlineShop/entitlements.nut")
let { getEntitlementView, getEntitlementLayerIconsConfig } = require("%scripts/onlineShop/entitlementView.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_command } = require("console")

const MAX_REWARDS_SHOW_IN_ENTITLEMENT = 9

gui_handlers.EntitlementRewardWnd <- class (gui_handlers.trophyRewardWnd) {
  wndType = handlerType.MODAL

  entitlementConfig = null

  chestDefaultImg = "every_day_award_trophy_big"

  prepareParams = @() null
  getTitle = @() getEntitlementName(this.entitlementConfig)
  isRouletteStarted = @() false
  notVisibleItemsCount = 0
  viewParams = null

  function openChest() {
    if (this.opened)
      return false

    this.opened = true
    this.updateWnd()
    return true
  }

  function checkConfigsArray() {
    let unitNames = this.entitlementConfig?.aircraftGift ?? []
    if (unitNames.len())
      this.unit = getAircraftByName(unitNames[0])

    let decalsNames = this.entitlementConfig?.decalGift ?? []
    let attachablesNames = this.entitlementConfig?.attachableGift ?? []
    let skinsNames = this.entitlementConfig?.skinGift ?? []
    local resourceType = ""
    local resource = ""
    if (decalsNames.len()) {
      resourceType = "decal"
      resource = decalsNames[0]
    }
    else if (attachablesNames.len()) {
      resourceType = "attachable"
      resource = attachablesNames[0]
    }
    else if (skinsNames.len()) {
      resourceType = "skin"
      resource = skinsNames[0]
    }

    if (resource != "")
      this.updateResourceData(resource, resourceType)
  }

  function updateRewardPostscript() {
    if (!this.opened || !this.useSingleAnimation || this.notVisibleItemsCount <= 0)
      return

    let obj = this.scene.findObject("reward_postscript")
    if (!(obj?.isValid() ?? false))
      return
    obj.setValue(loc("trophy/moreRewards", { num = this.notVisibleItemsCount }))
  }

  function getIconData() {
    if (!this.opened)
      return ""

    let layersIconsData = getEntitlementLayerIconsConfig(
      this.entitlementConfig,
      { maxCount = MAX_REWARDS_SHOW_IN_ENTITLEMENT }
    )
    this.notVisibleItemsCount = layersIconsData.totalCount - layersIconsData.count

    return "{0}{1}".subst(
      LayersIcon.getIconData($"{this.chestDefaultImg}_opened"),
      layersIconsData.icons
    )
  }

  function updateRewardText() {
    if (!this.opened)
      return

    let obj = this.scene.findObject("prize_desc_div")
    if (!checkObj(obj))
      return

    let data = getEntitlementView(this.entitlementConfig, (this.viewParams ?? {}).__merge({
      header = loc("mainmenu/you_received")
      multiAwardHeader = true
      widthByParentParent = true
    }))

    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  checkSkipAnim = @() false
  notifyTrophyVisible = @() null
  updateRewardItem = @() null
}

function showEntitlement(entitlementId, params = {}) {
  let config = getEntitlementConfig(entitlementId)
  if (!config) {
    logerr($"Entitlement Reward: Could not find entitlement config {entitlementId}")
    return
  }

  handlersManager.loadHandler(gui_handlers.EntitlementRewardWnd, {
    entitlementConfig = config
    viewParams = params
  })
}

register_command(@(entId) showEntitlement(entId, { ignoreAvailability = true }),
  "ui.showEntitlement"
)

return {
  showEntitlement
}