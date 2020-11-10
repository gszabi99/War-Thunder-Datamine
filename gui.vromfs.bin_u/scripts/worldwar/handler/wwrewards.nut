local time = require("scripts/time.nut")

class ::gui_handlers.WwRewards extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanSeasonInfoModal.blk"

  isClanRewards = false
  rewardsBlk = null
  rewardsTime = 0
  lbMode    = null
  lbDay     = null
  lbMap     = null
  lbCountry = null

  rewardsListObj = null
  rewards = null

  function initScreen()
  {
    rewardsListObj = scene.findObject("rewards_list")
    if (!::check_obj(rewardsListObj))
      return goBack()

    local wndTitle = ::g_string.implode([
      (lbMode ? ::loc("worldwar/leaderboard/" + lbMode) : ""),
      (lbDay ? ::loc("enumerated_day", {number=lbDay}) : !isClanRewards ? ::loc("worldwar/allSeason") : ""),
      (lbMap ? lbMap.getNameText() : ::loc("worldwar/allMaps")),
      (lbCountry ? ::loc(lbCountry) : ::loc("worldwar/allCountries")),
    ], ::loc("ui/comma")) + " " + ::loc("ui/mdash") + " " + ::loc("worldwar/btn_rewards")
    scene.findObject("wnd_title").setValue(wndTitle)

    showSceneBtn("nav-help", true)
    updateRerwardsStartTime()

    rewards = []
    foreach (rewardBlk in rewardsBlk)
    {
      local reward = getRewardData(rewardBlk)
      if (!reward)
        continue

      local blockCount = rewardBlk.blockCount()
      if (blockCount)
      {
        reward.internalRewards <- []
        for (local i = 0; i < rewardBlk.blockCount(); i++)
        {
          local internalReward = getRewardData(rewardBlk.getBlock(i), false)
          if (internalReward)
            reward.internalRewards.append(internalReward)
        }
      }

      rewards.append(reward)
    }

    updateRewardsList()
  }

  function getRewardData(rewardBlk, needPlace = true)
  {
    local reward = {}
    for (local i = 0; i < rewardBlk.paramCount(); i++)
      reward[rewardBlk.getParamName(i)] <- rewardBlk.getParamValue(i)

    return (!needPlace || (reward?.tillPlace ?? 0)) ? reward : null
  }

  function getItemsMarkup(items)
  {
    local view = { items = [] }
    foreach (item in items)
      view.items.append(item.getViewData({
        ticketBuyWindow = false
        hasButton = false
        contentIcon = false
        hasTimer = false
        addItemName = false
        interactive = true
      }))

    return ::handyman.renderCached("gui/items/item", view)
  }

  function getPlaceText(tillPlace, prevPlace, isClan = false)
  {
    if (!tillPlace)
      tillPlace = ::g_clan_type.NORMAL.maxMembers
    return ::loc(isClan ? "multiplayer/clan_place" : "multiplayer/place") + ::loc("ui/colon")
      + ((tillPlace - prevPlace == 1) ? tillPlace : (prevPlace + 1) + ::loc("ui/mdash") + tillPlace)
  }

  function getRewardTitle(tillPlace, prevPlace)
  {
    if (!tillPlace)
      return ::loc("multiplayer/place/to_other")

    if (tillPlace - prevPlace == 1)
      return tillPlace <= 3
        ? ::loc("clan/season_award/place/place" + tillPlace)
        : ::loc("clan/season_award/place/placeN", { placeNum = tillPlace })

    return ::loc("clan/season_award/place/top", { top = tillPlace })
  }

  function getRewardsView()
  {
    local prevPlace = 0
    return {
      rewardsList = ::u.map(rewards, function(reward) {
        local rewardRowView = {
          title = getRewardTitle(reward.tillPlace, prevPlace)
          condition = getPlaceText(reward.tillPlace, prevPlace, isClanRewards)
        }
        prevPlace = reward.tillPlace

        local trophyId = reward?.itemdefid
        if (trophyId)
        {
          local trophyItem = ::ItemsManager.findItemById(trophyId)
          if (trophyItem)
          {
              rewardRowView.trophyMarkup <- getItemsMarkup([trophyItem])
              rewardRowView.trophyName <- trophyItem.getName()
          }
        }

        local internalRewards = reward?.internalRewards
        if (internalRewards)
        {
          rewardRowView.internalRewardsList <- []

          local internalRewardsList = []
          local internalPrevPlace = 0
          foreach (internalReward in internalRewards)
          {
            local internalTrophyId = internalReward?.itemdefid
            if (internalTrophyId)
            {
              local internalTrophyItem = ::ItemsManager.findItemById(internalTrophyId)
              if (internalTrophyItem)
                internalRewardsList.append({
                  internalTrophyMarkup = getItemsMarkup([internalTrophyItem])
                  internalCondition = getPlaceText(internalReward?.tillPlace, internalPrevPlace)
                })
            }
            internalPrevPlace = internalReward?.tillPlace ?? 0
          }
          if (internalRewardsList.len())
          {
            rewardRowView.internalRewardsList <- internalRewardsList
            rewardRowView.hasInternalRewards <- true
          }
        }

        return rewardRowView
      }.bindenv(this))
    }
  }

  function updateRerwardsStartTime()
  {
    local text = ""
    if (rewardsTime > 0)
      text = ::loc("worldwar/rewards_start_time") + ::loc("ui/colon") +
        time.buildDateTimeStr(rewardsTime, false, false)
    scene.findObject("statusbar_text").setValue(text)
  }

  function onBtnMoreInfo(obj)
  {
    local rewardsArray = []
    local addItem = @(item) ::u.appendOnce(item?.itemdefid, rewardsArray, true)
    rewards.each(@(reward) reward?.internalRewards.each(addItem) ?? addItem(reward))
    ::gui_start_open_trophy_rewards_list({
      rewardsArray = rewardsArray.map(@(reward) { item = reward })
    })
  }

  function onItemSelect(obj) {}

  function updateRewardsList()
  {
    local val = ::get_obj_valid_index(rewardsListObj)
    local markup = ::handyman.renderCached("gui/worldWar/wwRewardItem", getRewardsView())
    guiScene.replaceContentFromText(rewardsListObj, markup, markup.len(), this)

    if (val < 0 || val >= rewardsListObj.childrenCount())
      val = 0

    rewardsListObj.setValue(val)
  }

  function onEventItemsShopUpdate(obj)
  {
    updateRewardsList()
  }
}

return {
  open = function(params) {
    if (!params?.rewardsBlk)
      return

    ::handlersManager.loadHandler(::gui_handlers.WwRewards, params)
  }
}
