class ::gui_handlers.EventRewardsWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/events/eventRewardsWnd"

  event = null
  rewardsList = null

  static function open(_event)
  {
    if (!_event)
      return
    local rewards = ::EventRewards.getSortedRewardsByConditions(_event)
    if (!rewards.len() && !::EventRewards.getBaseVictoryReward(_event))
      return

    local params = {
      event = _event
      rewardsList = rewards
    }
    ::handlersManager.loadHandler(::gui_handlers.EventRewardsWnd, params)
  }

  function initScreen()
  {
    local view = {
      header     = ::loc("tournaments/rewards")
      total      = rewardsList.len()
      baseReward = (@(event) function () {
        local reward = ::EventRewards.getBaseVictoryReward(event)
        return reward ? ::loc("tournaments/reward/everyVictory",  {reward = reward}) : reward
      })(event)
      items = (@(rewardsList, event) function () {
        local even = true
        local res = []
        foreach(conditionName, condition in rewardsList)
          foreach (blk in condition)
          {
            even = !even
            local item = {
              conditionId     = conditionName
              conditionText   = ::EventRewards.getConditionText(blk)
              conditionValue  = ::EventRewards.getConditionValue(blk)
              conditionField  = ::EventRewards.getConditionField(blk)
              reward          = ::EventRewards.getRewardDescText(blk)
              icon            = ::EventRewards.getRewardRowIcon(blk)
              rewardTooltipId = ::EventRewards.getRewardTooltipId(blk)
              received        = ::EventRewards.isRewardReceived(blk, event)
              even            = even
            }
            res.append(item)
          }
        return res
      })(rewardsList, event)
    }

    local data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene.findObject("root-box"), data, data.len(), this)
    fetchRewardsProgress()
  }

  function fetchRewardsProgress()
  {
    foreach(conditionId, rewardsInCondition in rewardsList)
      foreach (blk in rewardsInCondition)
        if (!::EventRewards.isRewardReceived(blk, event))
          ::EventRewards.getCondition(conditionId)
                        .updateProgress(blk, event, (@(blk) function (progress) {
                            local condId = ::EventRewards.getRewardConditionId(blk)
                            local conditionValue = ::EventRewards.getConditionValue(blk)
                            local conditionField = ::EventRewards.getConditionField(blk)
                            local conditionTextObj = scene.findObject("reward_condition_text_" +
                                                                      condId + "_" +
                                                                      conditionField + "_" +
                                                                      conditionValue)
                            if (::checkObj(conditionTextObj))
                            {
                              local condition = ::EventRewards.getConditionText(blk, progress)
                              conditionTextObj.setValue(condition)
                            }
                          })(blk), this)
  }
}
