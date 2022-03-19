local performActionTable = {}
local visibilityByAction = {}

local addPromoAction = function(actionId, actionFunc, visibilityFunc = null) {
  performActionTable[actionId] <- actionFunc
  if (visibilityFunc != null)
    visibilityByAction[actionId] <- visibilityFunc
}

local getPromoAction = @(actionId) performActionTable?[actionId]

local isVisiblePromoByAction = @(actionId, params) visibilityByAction?[actionId](params) ?? true

return {
  addPromoAction
  getPromoAction
  isVisiblePromoByAction
}