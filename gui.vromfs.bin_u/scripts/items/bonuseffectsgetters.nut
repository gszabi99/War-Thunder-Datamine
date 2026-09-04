from "%appGlobals/ranks_common_shared.nut" import calc_boost_for_cyber_cafe, calc_boost_for_squads_members_from_same_cyber_cafe
from "%scripts/dagui_natives.nut" import get_cyber_cafe_level
from "%scripts/dagui_library.nut" import *

let { getSameCyberCafeMembersNum } = require("%scripts/squads/squadState.nut")

function getCyberCafeBonusByEffectType(effectType, cyberCafeLevel = -1) {
  if (cyberCafeLevel < 0)
    cyberCafeLevel = get_cyber_cafe_level()
  let cyberCafeBonusesTable = calc_boost_for_cyber_cafe(cyberCafeLevel)
  let value = cyberCafeBonusesTable?[effectType.abbreviation] ?? 0
  return value
}

function getSquadBonusForSameCyberCafe(effectType, num = -1) {
  if (num < 0)
    num = getSameCyberCafeMembersNum()
  let cyberCafeBonusesTable = calc_boost_for_squads_members_from_same_cyber_cafe(num)
  let value = cyberCafeBonusesTable?[effectType.abbreviation] ?? 0
  return value
}

return {
  getCyberCafeBonusByEffectType
  getSquadBonusForSameCyberCafe
}