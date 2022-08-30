let { buildDateTimeStr, getTimestampFromStringUtc } = require("%scripts/time.nut")

::gui_handlers.EventRewardsWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/events/eventRewardsWnd"
  rewardsTableTplName = "%gui/events/eventRewardsTbl"

  currTabIdx = 0
  //Incoming params
  tabsList = null

  static function open(params) {
    local tabsList = []
    foreach (tab in params) {
      let { event, tourId = null, header = null } = tab
      if (!event)
        continue

      if (!tourId)
        continue

      let tournamenBlk = ::get_tournament_desk_blk(tourId)
      let finalAwardDate = tournamenBlk?.finalAwardDate
      let rewards = ::EventRewards.getSortedRewardsByConditions(event, tournamenBlk?.awards)

      if (!rewards.len() && !::EventRewards.getBaseVictoryReward(event))
        continue

      tabsList.append({ header, event, rewards, finalAwardDate, tourId })
    }

    if (tabsList.len() == 0)
      return

    ::handlersManager.loadHandler(::gui_handlers.EventRewardsWnd, {tabsList})
  }

  function initScreen() {
    local tabs = []
    foreach (idx, tab in tabsList)
      tabs.append({
        id = idx.tostring()
        tabName = tab.header
        navImagesText = tabsList.len() > 1 ? ::get_navigation_images_text(idx, tabsList.len()) : ""
        selected = idx == 0
      })
    let data = ::handyman.renderCached(sceneTplName, {tabs})
    guiScene.replaceContentFromText(scene.findObject("root-box"), data, data.len(), this)

    updateRewards()
    fetchRewardsProgress()
  }

  function updateRewards() {
    let curTabData = tabsList?[currTabIdx]
    if (!curTabData)
      return

    let {event, rewards, finalAwardDate, tourId} = curTabData
    let eventEconomicName = finalAwardDate ? tourId : ::events.getEventEconomicName(event)
    let view = {
      total      = rewards.len()
      baseReward = (@(event) function () {
        let reward = ::EventRewards.getBaseVictoryReward(event)
        return reward ? ::loc("tournaments/reward/everyVictory",  {reward = reward}) : reward
      })(event)
      items = (@(rewards, event) function () {
        local even = true
        let res = []
        foreach(conditionName, condition in rewards)
          foreach (idx, blk in condition)
          {
            even = !even
            let item = {
              index           = idx
              conditionId     = conditionName
              conditionText   = ::EventRewards.getConditionText(blk)
              conditionValue  = ::EventRewards.getConditionValue(blk)
              conditionField  = ::EventRewards.getConditionField(blk)
              reward          = ::EventRewards.getRewardDescText(blk)
              icon            = ::EventRewards.getRewardRowIcon(blk)
              rewardTooltipId = ::EventRewards.getRewardTooltipId(blk)
              received        = ::EventRewards.isRewardReceived(blk, eventEconomicName)
              even            = even
            }
            res.append(item)
          }
        return res
      })(rewards, event)
    }

    let data = ::handyman.renderCached(rewardsTableTplName, view)
    guiScene.replaceContentFromText(scene.findObject("rewards_content"), data, data.len(), this)
  }

  function fetchRewardsProgress() {
    let curTabData = tabsList?[currTabIdx]
    if (!curTabData)
      return

    let {event, rewards, finalAwardDate, tourId} = curTabData
    let eventEconomicName = finalAwardDate ? tourId : ::events.getEventEconomicName(event)
    foreach(conditionId, rewardsInCondition in rewards)
      foreach (idx, blk in rewardsInCondition)
        if (!::EventRewards.isRewardReceived(blk, eventEconomicName)) {
          let index = idx
          let reward = blk
          ::EventRewards.getCondition(conditionId).updateProgress(blk, event, function (progress) {
              let condId = ::EventRewards.getRewardConditionId(reward)
              let conditionField = ::EventRewards.getConditionField(reward)
              let conditionTextObj = scene.findObject(
                $"reward_condition_text_{condId}_{conditionField}_{index}")
              if (conditionTextObj?.isValid())
                conditionTextObj.setValue(::EventRewards.getConditionText(reward, progress))
            }, this)}
  }

  function updateTabInfo() {
    let finalAwardDate = tabsList[currTabIdx].finalAwardDate
    let infoTxt = finalAwardDate
      ? "".concat(::loc("tournaments/rewardBeCredited"), " ",
        ::colorize("activeTextColor", buildDateTimeStr(getTimestampFromStringUtc(finalAwardDate))))
      : ""
    scene.findObject("info_txt")?.setValue(infoTxt)
  }

  function onTabChange(obj) {
    let curTabObj = obj.getChild(obj.getValue())
    if (!curTabObj?.isValid())
      return

    currTabIdx = curTabObj.id.tointeger()
    updateTabInfo()
    updateRewards()
    fetchRewardsProgress()
  }

}
