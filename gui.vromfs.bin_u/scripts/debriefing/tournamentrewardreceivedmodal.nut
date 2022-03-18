::gui_handlers.TournamentRewardReceivedWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
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
    let params = {
      rewardBlk = config
      eventEconomicName = config.eventId
    }
    return ::handlersManager.loadHandler(::gui_handlers.TournamentRewardReceivedWnd, params)
  }

  function initScreen()
  {
    let event = ::events.getEventByEconomicName(eventEconomicName)
    let nextReward = ::EventRewards.getNext(rewardBlk, event)

    let rewardDescriptionData = {
      tournamentName = ::colorize("userlogColoredText", ::events.getNameByEconomicName(eventEconomicName))
    }

    let mainConditionId = ::EventRewards.getRewardConditionId(rewardBlk)
    let view = {
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
    let blk = ::handyman.renderCached("%gui/tournamentRewardReceived", view)
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