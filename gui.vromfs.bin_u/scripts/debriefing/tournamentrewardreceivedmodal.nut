from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/events/eventRewards.nut" import getRewardCondition, getNextReward, getConditionIcon, getRewardIcon, getRewardDescText, getConditionText
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/unlocks/showUnlockWnd.nut" import checkDelayedUnlockWnd
from "%scripts/events/eventsManager.nut" import events
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")


let TournamentRewardReceivedWnd = class (BaseGuiHandlerWT) {
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  wndType = handlerType.MODAL

  


   rewardBlk = null

  



  eventEconomicName = null

  static function open(config) {
    let params = {
      rewardBlk = config
      eventEconomicName = config.eventId
    }
    return handlersManager.loadHandler(get_gui_handler("TournamentRewardReceivedWnd"), params)
  }

  function initScreen() {
    let event = events.getEventByEconomicName(this.eventEconomicName)
    let nextReward = getNextReward(this.rewardBlk, event)

    let rewardDescriptionData = {
      tournamentName = colorize("userlogColoredText", events.getNameByEconomicName(this.eventEconomicName))
    }

    let view = {
      rewardDescription = loc("tournaments/reward/description", rewardDescriptionData)
      conditionText     = getConditionText(this.rewardBlk)
      conditionIcon     = getConditionIcon(getRewardCondition(this.rewardBlk))
      rewardIcon        = getRewardIcon(this.rewardBlk)
      rewardText        = getRewardDescText(this.rewardBlk)
      nextReward        = null
    }

    if (nextReward)
      view.nextReward = {
        conditionText = getConditionText(nextReward)
        rewardIcon    = getRewardIcon(nextReward)
        rewardText    = getRewardDescText(nextReward)
      }
    let blk = handyman.renderCached("%gui/tournamentRewardReceived.tpl", view)
    this.guiScene.replaceContentFromText(this.scene.findObject("root-box"), blk, blk.len(), this)
  }

  function afterModalDestroy() {
    checkDelayedUnlockWnd()
  }

  function onOk(_obj) {
    this.goBack()
  }
}
register_gui_handler("TournamentRewardReceivedWnd", TournamentRewardReceivedWnd)