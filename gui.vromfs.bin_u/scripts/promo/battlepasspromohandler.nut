from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { seasonLvlWatchObj, hasBattlePassRewardWatchObj, hasChallengesRewardWatchObj
} = require("%scripts/battlePass/watchObjInfoConfig.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { PERFORM_PROMO_ACTION_NAME, performPromoAction, getPromoActionParamsKey,
  getPromoVisibilityById
} = require("%scripts/promo/promo.nut")

let BattlePassPromoHandler = class (gui_handlers.BaseGuiHandlerWT) {
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
        }
      ]
    }
  }

  function performAction(obj) { performPromoAction(this, obj) }
}

gui_handlers.BattlePassPromoHandler <- BattlePassPromoHandler

function openBattlePassPromoHandler(params) {
  handlersManager.loadHandler(BattlePassPromoHandler, params)
}

let promoButtonId = "battle_pass_mainmenu_button"

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
