from "%scripts/dagui_natives.nut" import get_skin_cost_wp, get_skin_cost_gold
from "%scripts/dagui_library.nut" import *
let regexp2 = require("regexp2")
let { Cost } = require("%scripts/money.nut")

const DEFAULT_SKIN_NAME = "default"

let unitNameReg = regexp2(@"[.*/].+")
let skinNameReg = regexp2(@"^[^/]*/")

let getSkinId           = @(unitName, skinName) $"{unitName}/{skinName}"
let getPlaneBySkinId    = @(id) unitNameReg.replace("", id)
let getSkinNameBySkinId = @(id) skinNameReg.replace("", id)
let isDefaultSkin       = @(id) getSkinNameBySkinId(id) == DEFAULT_SKIN_NAME

function getSkinCost(skinId) {
  let unitName = getPlaneBySkinId(skinId)
  return Cost(max(0, get_skin_cost_wp(unitName, skinId)), max(0, get_skin_cost_gold(unitName, skinId)))
}

return {
  getSkinId
  getSkinCost
  getPlaneBySkinId
  getSkinNameBySkinId
  isDefaultSkin
  DEFAULT_SKIN_NAME
}