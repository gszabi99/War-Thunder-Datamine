from "%scripts/dagui_library.nut" import *

let performActionTable = {}
let visibilityByAction = {}

function addPromoAction(actionId, actionFunc, visibilityFunc = null) {
  performActionTable[actionId] <- actionFunc
  if (visibilityFunc != null)
    visibilityByAction[actionId] <- visibilityFunc
}

let getPromoAction = @(actionId) performActionTable?[actionId]

let isVisiblePromoByAction = @(actionId, params) visibilityByAction?[actionId](params) ?? true

return {
  addPromoAction
  getPromoAction
  isVisiblePromoByAction
}