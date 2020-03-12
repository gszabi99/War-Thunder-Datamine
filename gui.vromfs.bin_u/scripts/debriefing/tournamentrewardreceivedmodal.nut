class ::gui_handlers.TournamentRewardReceivedWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  wndType = handlerType.MODAL

  /**
   * Reward data in same format as in eventRewards
   */
   rewardBlk = null

  /**
   * Event's economic name of tournaments
   * event, for which was reward earned
   */
  eventEconomicName = null

  static function open(config)
  {
    local params = {
      rewardBlk = config
      eventEconomicName = config.eventId
    }
    return ::handlersManager.loadHandler(::gui_handlers.TournamentRewardReceivedWnd, params)
  }

  function initScreen()
  {
    local event = ::events.getEventByEconomicName(eventEconomicName)
    local nextReward = ::EventRewards.getNext(rewardBlk, event)

    local rewardDescriptionData = {
      tournamentName = ::colorize("userlogColoredText", ::events.getNameByEconomicName(eventEconomicName))
    }

    local mainConditionId = ::EventRewards.getRewardConditionId(rewardBlk)
    local view = {
      rewardDescription = ::loc("tournaments/reward/description", rewardDescriptionData)
      conditionText     = ::EventRewards.getConditionText(rewardBlk)
      conditionIcon     = ::EventRewards.getConditionIcon(::EventRewards.getCondition(mainConditionId))
      rewardIcon        = ::EventRewards.getRewardIcon(rewardBlk)
      rewardText        = ::EventRewards.getRewardDescText(rewardBlk)
      nextReward        = null
    }

    if (nextReward)
      view.nextReward = {
        conditionText = ::EventRewards.getConditionText(nextReward)
        rewardIcon    = ::EventRewards.getRewardIcon(nextReward)
        rewardText    = ::EventRewards.getRewardDescText(nextReward)
      }
    local blk = ::handyman.renderCached("gui/tournamentRewardReceived", view)
    guiScene.replaceContentFromText(scene.findObject("root-box"), blk, blk.len(), this)

    ::show_facebook_screenshot_button(scene)
  }

  function afterModalDestroy()
  {
    ::check_delayed_unlock_wnd()
  }

  function onOk(obj)
  {
    goBack()
  }
}