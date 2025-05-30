from "%scripts/dagui_natives.nut" import shop_purchase_skillpoints, wp_get_skill_points_cost_gold
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { get_warpoints_blk } = require("blkGetters")

function getSkillPointsPacks(country) {
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

function getPacksToBuyAmount(country, skillPoints) {
  let packs = getSkillPointsPacks(country)
  if (!packs.len())
    return []

  let bestPack = packs.top() 
  return array((skillPoints.tofloat() / bestPack.skills + 0.5).tointeger(), bestPack)
}

return {
  getSkillPointsPacks
  getPacksToBuyAmount
}