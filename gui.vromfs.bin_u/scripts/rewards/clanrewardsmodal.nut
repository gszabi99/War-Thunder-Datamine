//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let DataBlock = require("DataBlock")
let { json_to_string } = require("json")
let { cutPrefix } = require("%sqstd/string.nut")
let { get_warpoints_blk } = require("blkGetters")
let { addTask } = require("%scripts/tasker.nut")

let function isRewardBest(medal, clanData) {
  if ((clanData?.clanBestRewards.len() ?? 0) > 0 && medal?.bestRewardsConfig)
    foreach (reward in clanData.clanBestRewards)
      if (u.isEqual(reward, medal.bestRewardsConfig))
        return true

  return false
}

let function isRewardVisible (medal, clanData) {
  if ((clanData?.clanBestRewards.len() ?? 0) == 0 || !medal?.bestRewardsConfig)
    return true

  foreach (reward in clanData.clanBestRewards)
    if (u.isEqual(reward, medal.bestRewardsConfig))
      return true

  return false
}

gui_handlers.clanRewardsModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType            = handlerType.MODAL
  sceneTplName       = "%gui/rewards/clanRewardsModal.tpl"
  rewards            = null
  clanId             = null
  canEditBestRewards = false
  bestIds            = []
  checkupIds         = []
  maxClanBestRewards = 6

  function getSceneTplView() {
    this.maxClanBestRewards = get_warpoints_blk()?.maxClanBestRewards ?? this.maxClanBestRewards
    let blocksCount = this.rewards.len() > 3 ? 2 : 1
    let myClanRights = ::g_clans.getMyClanRights()
    this.canEditBestRewards = this.clanId == ::clan_get_my_clan_id() && isInArray("CHANGE_INFO", myClanRights)
    return {
      width = blocksCount + "@unlockBlockWidth + " + (blocksCount - 1) + "@framePadding"
      isEditable = this.canEditBestRewards

      rewards = this.rewards.map(@(reward, idx) {
        rewardImage = LayersIcon.getIconData(reward.iconStyle, null, null, null,
          reward.iconParams, reward.iconConfig)
        rewardId = "reward_" + idx
        award_title_text = reward.name
        desc_text = reward.desc
        isChecked = isRewardBest(reward, ::my_clan_info) ? "yes" : "no"
      })
    }
  }

  function initScreen() {
    this.fillBestRewardsIds()
    move_mouse_on_child(this.scene.findObject("rewards_list"), 0)
  }

  function fillBestRewardsIds() {
    this.bestIds = []
    if (this.canEditBestRewards)
     foreach (idx, reward in this.rewards)
       if (isRewardBest(reward, ::my_clan_info))
         this.bestIds.append(idx)
    this.checkupIds = clone this.bestIds
  }

  function updateBestRewardsIds(id, isChecked) {
    let rIdx = cutPrefix(id, "reward_").tointeger()
    let bridx = this.bestIds.findindex(@(i) i == rIdx)
    if (bridx == null && isChecked)
      this.bestIds.append(rIdx)
    if (bridx != null && !isChecked)
      this.bestIds.remove(bridx)
  }

  function getBestRewardsConfig() {
    let bestRewards = []
    foreach (id in this.bestIds)
      bestRewards.append(this.rewards[id].bestRewardsConfig)

    return bestRewards
  }

  function onBestRewardSelect(obj) {
    if (!checkObj(obj))
      return

    let isChecked = obj.getValue()
    if (this.bestIds.len() == this.maxClanBestRewards && isChecked) {
      obj.setValue(false)
      obj.tooltip = loc("clan/clan_awards/hint/favoritesLimit")
      ::g_popups.add(null, loc("clan/clan_awards/hint/favoritesLimit"))
      return
    }
    obj.tooltip = loc(isChecked
      ? "mainmenu/UnlockAchievementsRemoveFromFavorite/hint"
      : "mainmenu/UnlockAchievementsToFavorite/hint")
    this.updateBestRewardsIds(obj.id, isChecked)
  }

  function goBack() {
    base.goBack()
    if (! this.canEditBestRewards || u.isEqual(this.bestIds, this.checkupIds))
      return

    let taskId = ::char_send_custom_action("cln_set_clan_best_rewards",
      EATT_SIMPLE_OK,
      DataBlock(),
      json_to_string({ clanId = this.clanId, bestRewards = this.getBestRewardsConfig() }, false),
      -1)
    addTask(taskId, { showProgressBox = false })
    ::sync_handler_simulate_signal("clan_info_reload")
  }

  function onActivate(obj) {
    let childrenCount = obj.childrenCount()
    let idx = obj.getValue()
    if (idx < 0 || idx >= childrenCount)
      return

    let checkBoxObj = obj.getChild(idx).findObject("reward_" + idx)
    if (!checkObj(checkBoxObj))
      return

    checkBoxObj.setValue(!checkBoxObj.getValue())
  }
}

return {
  open = function(params = null) {
    handlersManager.loadHandler(gui_handlers.clanRewardsModal, params)
  }
  isRewardVisible = isRewardVisible
}