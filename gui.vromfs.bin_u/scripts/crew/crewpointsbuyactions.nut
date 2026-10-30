import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/money.nut" import Cost
from "%scripts/tasker.nut" import addTask
from "%scripts/viewUtils/objectTextUpdate.nut" import warningIfGold
from "%scripts/user/balanceFeatures.nut" import checkBalanceMsgBox
from "%scripts/crew/crewPointsText.nut" import getCrewSpTextIfNotZero
from "%scripts/purchase/purchaseConfirmationHandler.nut" import purchaseConfirmation
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import shop_purchase_skillpoints

function buyPackImpl(crew, packsList, onSuccess) {
  let pack = packsList.remove(0)
  let taskId = shop_purchase_skillpoints(crew.id, pack.name)
  let self = callee()
  let cb = function() {
    broadcastEvent("CrewSkillsChanged", { crew = crew, isOnlyPointsChanged = true })
    if (packsList.len())
      self(crew, packsList, onSuccess)
    else if (onSuccess)
      onSuccess()
  }
  addTask(taskId, { showProgressBox = true }, cb)
}


function buySkillPointsPack(crew, packsList, onSuccess = null, onCancel = @() null) {
  if (!u.isArray(packsList))
    packsList = [packsList]
  local cost = Cost()
  local amount = 0
  foreach (pack in packsList) {
    amount += pack.skills
    cost += pack.cost
  }
  let locParams = {
    amount = getCrewSpTextIfNotZero(amount)
    cost = cost.getTextAccordingToBalance()
  }

  let text = warningIfGold(loc("shop/needMoneyQuestion_buySkillPoints", locParams), cost)
  let callbackYes =  @() checkBalanceMsgBox(cost)
    ? buyPackImpl(crew, packsList, onSuccess)
    : null

  purchaseConfirmation(
    { id = "purchase_ask", text, callbackYes, callbackNo = onCancel, onExitFunc = onCancel },
    cost
  )
}

return freeze({
  buySkillPointsPack
})