//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let itemInfoHandler = require("%scripts/items/itemInfoHandler.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_start_open_trophy_rewards_list <- function gui_start_open_trophy_rewards_list(params = {}) {
  let rewardsArray = params?.rewardsArray
  if (!rewardsArray || !rewardsArray.len())
    return

  ::gui_start_modal_wnd(::gui_handlers.trophyRewardsList, params)
}

::gui_handlers.trophyRewardsList <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/trophyRewardsList.blk"

  rewardsArray = []
  titleLocId = "mainmenu/rewardsList"

  infoHandler = null

  function initScreen() {
    let listObj = this.scene.findObject("items_list")
    if (!checkObj(listObj))
      return this.goBack()

    this.infoHandler = itemInfoHandler(this.scene.findObject("item_info"))

    let titleObj = this.scene.findObject("title")
    if (checkObj(titleObj))
      titleObj.setValue(loc(this.titleLocId))

    this.fillList(listObj)

    if (this.rewardsArray.len() > 4)
      listObj.width = (listObj.getSize()[0] + to_pixels("1@scrollBarSize")).tostring()

    listObj.setValue(this.rewardsArray.len() > 0 ? 0 : -1)
    ::move_mouse_on_child_by_value(listObj)
  }

  function fillList(listObj) {
    let data = this.getItemsImages()
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function getItemsImages() {
    local data = ""
    foreach (_idx, reward in this.rewardsArray)
      data += ::trophyReward.getImageByConfig(reward, false, "trophy_reward_place", true)

    return data
  }

  function updateItemInfo(obj) {
    let val = obj.getValue()
    let reward_config = this.rewardsArray[val]
    let rewardType = ::trophyReward.getType(reward_config)
    let isItem = ::trophyReward.isRewardItem(rewardType)
    this.infoHandler?.setHandlerVisible(isItem)
    let prizeInfo = this.showSceneBtn("prize_info", !isItem)
    if (isItem) {
      if (!this.infoHandler)
        return

      let item = ::ItemsManager.findItemById(reward_config[rewardType])
      this.infoHandler.updateHandlerData(item, true, true, reward_config)
      return
    }
    let trophyDesc = ::trophyReward.getFullDescriptonView(reward_config)
    this.guiScene.replaceContentFromText(prizeInfo, trophyDesc, trophyDesc.len(), this)
  }

  function onEventItemsShopUpdate(_p) {
    let listObj = this.scene.findObject("items_list")
    if (!checkObj(listObj))
      return

    this.fillList(listObj)
    if (listObj.childrenCount() > 0 && listObj.getValue() < 0)
      listObj.setValue(0)
    ::move_mouse_on_child_by_value(listObj)
  }
}
