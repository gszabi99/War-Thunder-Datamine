from "%scripts/battlePass/seasonState.nut" import seasonEndsTime
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut" import stashBhvValueConfig
from "%scripts/promo/promoButtonsConfig.nut" import addPromoButtonConfig
from "%scripts/promo/promo.nut" import PERFORM_PROMO_ACTION_NAME, performPromoAction, getPromoActionParamsKey, getPromoVisibilityById
from "%appGlobals/timeLoc.nut" import hoursToString
from "chard" import get_charserver_time_sec
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { seasonLvlWatchObj, hasBattlePassRewardWatchObj, hasChallengesRewardWatchObj, seasonEndsTimeWatchObj } = require("%scripts/battlePass/watchObjInfoConfig.nut")

let BattlePassPromoHandler = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/promo/promoBattlePass.tpl"

  function getSceneTplView() {
    return {
      performActionId = getPromoActionParamsKey(this.scene.id)
      action = PERFORM_PROMO_ACTION_NAME
      seasonLvlValue = stashBhvValueConfig(seasonLvlWatchObj)
      rewards = [{
          rewardText = "#mainmenu/fulfilledChallenges"
          rewardIcon = "#ui/gameuiskin#new_reward_icon.svg"
          hasRewardValue = stashBhvValueConfig(hasChallengesRewardWatchObj)
        },
        {
          rewardText = "#mainmenu/rewardsNotCollected"
          rewardIcon = "#ui/gameuiskin#new_icon.svg"
          hasRewardValue = stashBhvValueConfig(hasBattlePassRewardWatchObj)
        },
        {
          rewardText = "#mainmenu/seasonExpiredSoon"
          rewardIcon = "#ui/gameuiskin#alarmclock_icon.svg"
          hasRewardValue = stashBhvValueConfig(seasonEndsTimeWatchObj)
          id = "season_expired_label"
        }
      ]
    }
  }

  function initScreen() {
    base.initScreen()
    let timer = this.scene.findObject("expired_timer")
    timer.setUserData(this)
    this.updateExpiredTime(timer, 0)
  }

  function updateExpiredTime(obj, _dt) {
    let expiredSec = (seasonEndsTime.get() - get_charserver_time_sec())
    let seasonExpiredDays = expiredSec / (24 * 60 * 60)

    let needShow = (seasonExpiredDays >= 0) && (seasonExpiredDays <= 7)
    let expiredObj = showObjById("season_expired_label", needShow, obj.getParent())
    if (!needShow)
      return

    let textObj = expiredObj.findObject("promo_reward_text")
    textObj.setValue(loc("mainmenu/seasonExpiredSoon", {time = hoursToString(expiredSec / 3600.0)}))
  }

  function performAction(obj) { performPromoAction(this, obj) }
}

register_gui_handler("BattlePassPromoHandler", BattlePassPromoHandler)

function openBattlePassPromoHandler(params) {
  handlersManager.loadHandler(BattlePassPromoHandler, params)
}

const promoButtonId = "battle_pass_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "battlePass"
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = getPromoVisibilityById(id)
    let buttonObj = showObjById(id, show, this.scene)
    if (!show || !(buttonObj?.isValid() ?? false))
      return

    openBattlePassPromoHandler({ scene = buttonObj })
  }
})
