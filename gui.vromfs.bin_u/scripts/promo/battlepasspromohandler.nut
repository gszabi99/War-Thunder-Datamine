local { seasonLvlWatchObj, hasBattlePassRewardWatchObj, hasChallengesRewardWatchObj
} = require("scripts/battlePass/watchObjInfoConfig.nut")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")
local { addPromoButtonConfig } = require("scripts/promo/promoButtonsConfig.nut")

local BattlePassPromoHandler = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/promo/promoBattlePass"

  function getSceneTplView() {
    return {
      performActionId = ::g_promo.getActionParamsKey(scene.id)
      action = ::g_promo.PERFORM_ACTON_NAME
      seasonLvlValue = stashBhvValueConfig(seasonLvlWatchObj)
      rewards = [{
          rewardText = "#mainmenu/fulfilledChallenges"
          rewardIcon = "#ui/gameuiskin#new_reward_icon"
          hasRewardValue = stashBhvValueConfig(hasChallengesRewardWatchObj)
        },
        {
          rewardText = "#mainmenu/rewardsNotCollected"
          rewardIcon = "#ui/gameuiskin#new_icon"
          hasRewardValue = stashBhvValueConfig(hasBattlePassRewardWatchObj)
        }
      ]
    }
  }

  function performAction(obj) { ::g_promo.performAction(this, obj) }
}

::gui_handlers.BattlePassPromoHandler <- BattlePassPromoHandler

local function openBattlePassPromoHandler(params) {
  ::handlersManager.loadHandler(BattlePassPromoHandler, params)
}

local promoButtonId = "battle_pass_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "battlePass"
  updateFunctionInHandler = function() {
    local id = promoButtonId
    local show = ::g_promo.getVisibilityById(id)
    local buttonObj = ::showBtn(id, show, scene)
    if (!show || !(buttonObj?.isValid() ?? false))
      return

    openBattlePassPromoHandler({ scene = buttonObj })
  }
})
