from "%scripts/dagui_natives.nut" import shop_purchase_skillpoints, wp_get_skill_points_cost_gold
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_warpoints_blk } = require("blkGetters")
let { ceil } = require("math")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addTask } = require("%scripts/tasker.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getCrewSpTextIfNotZero } = require("%scripts/crew/crewPointsText.nut")

::g_crew_points <- {}

::g_crew_points.getSkillPointsPacks <- function getSkillPointsPacks(country) {
  let res = []
  let blk = get_warpoints_blk()
  if (!blk?.crewSkillPointsCost)
    return res

  foreach (block in blk.crewSkillPointsCost) {
    local blkName = block.getBlockName()
    res.append({
      name = blkName
      cost = Cost(0, wp_get_skill_points_cost_gold(blkName, country))
      skills = block?.crewExp ?? 1
    })
  }

  return res
}

//pack can be a single pack or packs array
::g_crew_points.buyPack <- function buyPack(crew, packsList, onSuccess = null, onCancel = @() null) {
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
    [["yes", Callback(function() {
        if (checkBalanceMsgBox(cost))
          this.buyPackImpl(crew, packsList, onSuccess)
      }, this)
    ], ["no", onCancel]], "yes", { cancel_fn = onCancel })
}

::g_crew_points.buyPackImpl <- function buyPackImpl(crew, packsList, onSuccess) {
  let pack = packsList.remove(0)
  let taskId = shop_purchase_skillpoints(crew.id, pack.name)
  let cb = Callback(function() {
    broadcastEvent("CrewSkillsChanged", { crew = crew, isOnlyPointsChanged = true })
    if (packsList.len())
      this.buyPackImpl(crew, packsList, onSuccess)
    else if (onSuccess)
      onSuccess()
  }, this)
  addTask(taskId, { showProgressBox = true }, cb)
}

::g_crew_points.getPacksToBuyAmount <- function getPacksToBuyAmount(country, skillPoints) {
  let packs = this.getSkillPointsPacks(country)
  if (!packs.len())
    return []

  let bestPack = packs.top() //while it only for developers it enough
  return array(ceil(skillPoints.tofloat() / bestPack.skills), bestPack)
}