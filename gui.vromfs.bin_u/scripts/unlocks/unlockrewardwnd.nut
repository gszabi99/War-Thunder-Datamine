from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getUnlockTypeText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.UnlockRewardWnd <- class extends ::gui_handlers.trophyRewardWnd {
  wndType = handlerType.MODAL

  unlockConfig = null
  unlockConditions = null
  unlockData = null

  chestDefaultImg = "every_day_award_trophy_big"
  itemContainerLayer = "trophy_reward_place"

  prepareParams = @() null
  getTitle = @() getUnlockTypeText(this.unlockData.type, this.unlockData.id)
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
    let unlockType = ::g_unlock_view.getUnlockType(this.unlockData)
    if (unlockType == UNLOCKABLE_AIRCRAFT)
      this.unit = ::getAircraftByName(this.unlockData.id)
    else if (unlockType == UNLOCKABLE_DECAL
      || unlockType == UNLOCKABLE_SKIN
      || unlockType == UNLOCKABLE_ATTACHABLE)
      {
        this.updateResourceData(this.unlockData.id, unlockType)
      }
  }

  function getIconData() {
    if (!this.opened)
      return ""

    let imgConfig = ::g_unlock_view.getUnlockImageConfig(this.unlockData)

    return "{0}{1}".subst(
      ::LayersIcon.getIconData($"{this.chestDefaultImg}_opened"),
      ::LayersIcon.genDataFromLayer(
        ::LayersIcon.findLayerCfg(this.itemContainerLayer),
        ::LayersIcon.getIconData(imgConfig.style, imgConfig.image, imgConfig.ratio, null, imgConfig.params)
      )
    )
  }

  function updateRewardText() {
    if (!this.opened)
      return

    let obj = this.scene.findObject("prize_desc_div")
    if (!checkObj(obj))
      return

    let data = ::g_unlock_view.getViewItem(this.unlockData, (this.viewParams ?? {}).__merge({
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
  showUnlock = function(unlockId, viewParams = {}) {
    let config = ::g_unlocks.getUnlockById(unlockId)
    if (!config)
    {
      logerr($"Unlock Reward: Could not find unlock config {unlockId}")
      return
    }

    let unlockConditions = ::build_conditions_config(config)
    ::handlersManager.loadHandler(::gui_handlers.UnlockRewardWnd, {
      unlockConfig = config
      unlockConditions = unlockConditions
      unlockData = ::build_log_unlock_data(unlockConditions)
      viewParams = viewParams
    })
  }
}