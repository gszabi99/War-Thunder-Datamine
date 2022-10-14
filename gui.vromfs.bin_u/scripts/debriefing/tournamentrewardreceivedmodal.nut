from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { getRewardCondition, getNextReward, getConditionIcon, getRewardIcon, getRewardDescText,
  getConditionText } = require("%scripts/events/eventRewards.nut")
  let { handlerType } = require("%sqDagui/framework/handlerType.nut")


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
    let nextReward = getNextReward(rewardBlk, event)

    let rewardDescriptionData = {
      tournamentName = colorize("userlogColoredText", ::events.getNameByEconomicName(eventEconomicName))
    }

    let view = {
      rewardDescription = loc("tournaments/reward/description", rewardDescriptionData)
      conditionText     = getConditionText(rewardBlk)
      conditionIcon     = getConditionIcon(getRewardCondition(rewardBlk))
      rewardIcon        = getRewardIcon(rewardBlk)
      rewardText        = getRewardDescText(rewardBlk)
      nextReward        = null
    }

    if (nextReward)
      view.nextReward = {
        conditionText = getConditionText(nextReward)
        rewardIcon    = getRewardIcon(nextReward)
        rewardText    = getRewardDescText(nextReward)
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