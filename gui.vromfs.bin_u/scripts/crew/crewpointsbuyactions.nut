from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import shop_purchase_skillpoints
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addTask } = require("%scripts/tasker.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getCrewSpTextIfNotZero } = require("%scripts/crew/crewPointsText.nut")

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

  let msgText = warningIfGold(loc("shop/needMoneyQuestion_buySkillPoints", locParams), cost)
  scene_msg_box("purchase_ask", null, msgText,
    [
      ["yes", function() {
        if (checkBalanceMsgBox(cost))
          buyPackImpl(crew, packsList, onSuccess)
      }],
      ["no", onCancel]
    ],
    "yes",
    { cancel_fn = onCancel }
  )
}

return {
  buySkillPointsPack
}