from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { seasonLvlWatchObj, hasBattlePassRewardWatchObj, hasChallengesRewardWatchObj
} = require("%scripts/battlePass/watchObjInfoConfig.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")

let BattlePassPromoHandler = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/promo/promoBattlePass.tpl"

  function getSceneTplView() {
    return {
      performActionId = ::g_promo.getActionParamsKey(this.scene.id)
      action = ::g_promo.PERFORM_ACTON_NAME
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

  function performAction(obj) { ::g_promo.performAction(this, obj) }
}

::gui_handlers.BattlePassPromoHandler <- BattlePassPromoHandler

let function openBattlePassPromoHandler(params) {
  ::handlersManager.loadHandler(BattlePassPromoHandler, params)
}

let promoButtonId = "battle_pass_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "battlePass"
  updateFunctionInHandler = function() {
    let id = promoButtonId
    let show = ::g_promo.getVisibilityById(id)
    let buttonObj = ::showBtn(id, show, this.scene)
    if (!show || !(buttonObj?.isValid() ?? false))
      return

    openBattlePassPromoHandler({ scene = buttonObj })
  }
})
