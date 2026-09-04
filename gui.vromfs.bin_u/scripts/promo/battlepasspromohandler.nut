from "%appGlobals/timeLoc.nut" import hoursToString
from "chard" import get_charserver_time_sec
from "%scripts/dagui_library.nut" import *

let { seasonEndsTime } = require("%scripts/battlePass/seasonState.nut")
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { seasonLvlWatchObj, hasBattlePassRewardWatchObj, hasChallengesRewardWatchObj, seasonEndsTimeWatchObj } = require("%scripts/battlePass/watchObjInfoConfig.nut")
let { stashBhvValueConfig } = require("%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { PERFORM_PROMO_ACTION_NAME, performPromoAction, getPromoActionParamsKey, getPromoVisibilityById } = require("%scripts/promo/promo.nut")

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
