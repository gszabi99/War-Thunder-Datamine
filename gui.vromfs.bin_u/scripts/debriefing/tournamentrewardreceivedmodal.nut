from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getRewardCondition, getNextReward, getConditionIcon, getRewardIcon, getRewardDescText,
  getConditionText } = require("%scripts/events/eventRewards.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let { checkDelayedUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")

let events = getGlobalModule("events")

gui_handlers.TournamentRewardReceivedWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  wndType = handlerType.MODAL

  


   rewardBlk = null

  



  eventEconomicName = null

  static function open(config) {
    let params = {
      rewardBlk = config
      eventEconomicName = config.eventId
    }
    return handlersManager.loadHandler(gui_handlers.TournamentRewardReceivedWnd, params)
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