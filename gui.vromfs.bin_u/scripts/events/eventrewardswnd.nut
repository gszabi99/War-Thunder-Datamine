::gui_handlers.EventRewardsWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/events/eventRewardsWnd"

  event = null
  rewardsList = null

  static function open(v_event)
  {
    if (!v_event)
      return
    let rewards = ::EventRewards.getSortedRewardsByConditions(v_event)
    if (!rewards.len() && !::EventRewards.getBaseVictoryReward(v_event))
      return

    let params = {
      event = v_event
      rewardsList = rewards
    }
    ::handlersManager.loadHandler(::gui_handlers.EventRewardsWnd, params)
  }

  function initScreen()
  {
    let view = {
      header     = ::loc("tournaments/rewards")
      total      = rewardsList.len()
      baseReward = (@(event) function () {
        let reward = ::EventRewards.getBaseVictoryReward(event)
        return reward ? ::loc("tournaments/reward/everyVictory",  {reward = reward}) : reward
      })(event)
      items = (@(rewardsList, event) function () {
        local even = true
        let res = []
        foreach(conditionName, condition in rewardsList)
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
              received        = ::EventRewards.isRewardReceived(blk, event)
              even            = even
            }
            res.append(item)
          }
        return res
      })(rewardsList, event)
    }

    let data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene.findObject("root-box"), data, data.len(), this)
    fetchRewardsProgress()
  }

  function fetchRewardsProgress()
  {
    foreach(conditionId, rewardsInCondition in rewardsList)
      foreach (idx, blk in rewardsInCondition)
        if (!::EventRewards.isRewardReceived(blk, event))
        {
          let index = idx
          let reward = blk
          ::EventRewards.getCondition(conditionId)
                        .updateProgress(blk, event, function (progress) {
                            let condId = ::EventRewards.getRewardConditionId(reward)
                            let conditionField = ::EventRewards.getConditionField(reward)
                            let conditionTextObj = scene.findObject("reward_condition_text_" +
                                                                      condId + "_" +
                                                                      conditionField + "_" +
                                                                      index)
                            if (::checkObj(conditionTextObj))
                            {
                              let condition = ::EventRewards.getConditionText(reward, progress)
                              conditionTextObj.setValue(condition)
                            }
        }, this)}
  }
}
