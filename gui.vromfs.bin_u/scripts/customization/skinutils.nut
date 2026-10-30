from "%scripts/money.nut" import Cost
from "string" import split_by_chars
from "%scripts/dagui_natives.nut" import get_skin_cost_wp, get_skin_cost_gold
from "%scripts/dagui_library.nut" import *

const DEFAULT_SKIN_NAME = "default"
let approversUnitToPreviewLiveResource = mkWatchedClearedOnReload(null)

let namesBySkinId = {}

function cacheNamesBySkinId(id) {
  if (id in namesBySkinId)
    return

  let [ unitName, skinName = "" ] = split_by_chars(id, "/")
  namesBySkinId[id] <- { unitName, skinName }
}

let getSkinId           = @(unitName, skinName) $"{unitName}/{skinName}"
function getPlaneBySkinId(id) {
  cacheNamesBySkinId(id)
  return namesBySkinId[id].unitName
}
function getSkinNameBySkinId(id) {
  cacheNamesBySkinId(id)
  return namesBySkinId[id].skinName
}
let isDefaultSkin       = @(id) getSkinNameBySkinId(id) == DEFAULT_SKIN_NAME

function getSkinCost(skinId) {
  let unitName = getPlaneBySkinId(skinId)
  return Cost(max(0, get_skin_cost_wp(unitName, skinId)), max(0, get_skin_cost_gold(unitName, skinId)))
}

return freeze({
  getSkinId
  getSkinCost
  getPlaneBySkinId
  getSkinNameBySkinId
  isDefaultSkin
  DEFAULT_SKIN_NAME
  approversUnitToPreviewLiveResource
})