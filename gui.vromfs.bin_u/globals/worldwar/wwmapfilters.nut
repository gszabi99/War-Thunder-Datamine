import "%globalScripts/sharedWatched.nut" as sharedWatched
from "worldwarConst" import RenderCategory

let isShowZonesFilter = sharedWatched("isShowZonesFilter", @() true)
let isShowPathForSelectedArmyFilter = sharedWatched("isShowPathForSelectedArmyFilter", @() true)
let isShowBattlesFilter = sharedWatched("isShowBattlesFilter", @() true)

let categoryFilter = {
  [RenderCategory.ERC_ZONES] = isShowZonesFilter,
  [RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES] = isShowPathForSelectedArmyFilter,
  [RenderCategory.ERC_BATTLES] = isShowBattlesFilter
}

return freeze({
  setWWMapFilter = @(category, enabled) categoryFilter?[category].set(enabled)
  isShowZonesFilter
  isShowPathForSelectedArmyFilter
  isShowBattlesFilter
})