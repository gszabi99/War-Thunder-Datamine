from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let function isRewardBest(medal, clanData) {
  if((clanData?.clanBestRewards.len() ?? 0) > 0 && medal?.bestRewardsConfig)
    foreach(reward in clanData.clanBestRewards)
      if(::u.isEqual(reward, medal.bestRewardsConfig))
        return true

  return false
}

let function isRewardVisible (medal, clanData)
{
  if((clanData?.clanBestRewards.len() ?? 0) == 0 || !medal?.bestRewardsConfig)
    return true

  foreach(reward in clanData.clanBestRewards)
    if(::u.isEqual(reward, medal.bestRewardsConfig))
      return true

  return false
}

::gui_handlers.clanRewardsModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType            = handlerType.MODAL
  sceneTplName       = "%gui/rewards/clanRewardsModal"
  rewards            = null
  clanId             = null
  canEditBestRewards = false
  bestIds            = []
  checkupIds         = []
  maxClanBestRewards = 6

  function getSceneTplView()
  {
    maxClanBestRewards = ::get_warpoints_blk()?.maxClanBestRewards ?? maxClanBestRewards
    let blocksCount = rewards.len() > 3 ? 2 : 1
    let myClanRights = ::g_clans.getMyClanRights()
    canEditBestRewards = clanId == ::clan_get_my_clan_id() && isInArray("CHANGE_INFO", myClanRights)
    return {
      width = blocksCount + "@unlockBlockWidth + " + (blocksCount - 1) + "@framePadding"
      isEditable = canEditBestRewards

      rewards = rewards.map(@(reward, idx) {
        rewardImage = ::LayersIcon.getIconData(reward.iconStyle, null, null, null,
          reward.iconParams, reward.iconConfig)
        rewardId = "reward_"+idx
        award_title_text = reward.name
        desc_text = reward.desc
        isChecked = isRewardBest(reward, ::my_clan_info) ? "yes" : "no"
      })
    }
  }

  function initScreen()
  {
    fillBestRewardsIds()
    ::move_mouse_on_child(scene.findObject("rewards_list"), 0)
  }

  function fillBestRewardsIds()
  {
    bestIds = []
    if(canEditBestRewards)
     foreach(idx, reward in rewards)
       if(isRewardBest(reward, ::my_clan_info))
         bestIds.append(idx)
    checkupIds = clone bestIds
  }

  function updateBestRewardsIds(id, isChecked)
  {
    let rIdx = ::g_string.cutPrefix(id, "reward_").tointeger()
    let bridx = bestIds.findindex(@(i) i == rIdx)
    if(bridx == null && isChecked)
      bestIds.append(rIdx)
    if(bridx != null && !isChecked)
      bestIds.remove(bridx)
  }

  function getBestRewardsConfig()
  {
    let bestRewards = []
    foreach(id in bestIds)
      bestRewards.append(rewards[id].bestRewardsConfig)

    return bestRewards
  }

  function onBestRewardSelect(obj)
  {
    if (!checkObj(obj))
      return

    let isChecked = obj.getValue()
    if(bestIds.len() == maxClanBestRewards && isChecked)
    {
      obj.setValue(false)
      obj.tooltip = loc("clan/clan_awards/hint/favoritesLimit")
      ::g_popups.add(null, loc("clan/clan_awards/hint/favoritesLimit"))
      return
    }
    obj.tooltip = loc(isChecked
      ? "mainmenu/UnlockAchievementsRemoveFromFavorite/hint"
      : "mainmenu/UnlockAchievementsToFavorite/hint")
    updateBestRewardsIds(obj.id, isChecked)
  }

  function goBack()
  {
    base.goBack()
    if (! canEditBestRewards || ::u.isEqual(bestIds, checkupIds))
      return

    let taskId = ::char_send_custom_action("cln_set_clan_best_rewards",
      EATT_SIMPLE_OK,
      ::DataBlock(),
      ::json_to_string({clanId = clanId, bestRewards = getBestRewardsConfig()}, false),
      -1)
    ::g_tasker.addTask(taskId, {showProgressBox = false})
    ::sync_handler_simulate_signal("clan_info_reload")
  }

  function onActivate(obj)
  {
    let childrenCount = obj.childrenCount()
    let idx = obj.getValue()
    if (idx < 0 || idx >= childrenCount)
      return

    let checkBoxObj = obj.getChild(idx).findObject("reward_"+idx)
    if (!checkObj(checkBoxObj))
      return

    checkBoxObj.setValue(!checkBoxObj.getValue())
  }
}

return {
  open = function(params=null)
  {
    ::handlersManager.loadHandler(::gui_handlers.clanRewardsModal, params)
  }
  isRewardVisible = isRewardVisible
}