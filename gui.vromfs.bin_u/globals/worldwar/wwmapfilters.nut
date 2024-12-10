let sharedWatched = require("%globalScripts/sharedWatched.nut")

let isShowZonesFilter = sharedWatched("isShowZonesFilter", @() true)
let isShowPathForSelectedArmyFilter = sharedWatched("isShowPathForSelectedArmyFilter", @() true)
let isShowBattlesFilter = sharedWatched("isShowBattlesFilter", @() true)
let { RenderCategory } = require("worldwarConst")

let categoryFilter = {
  [RenderCategory.ERC_ZONES] = isShowZonesFilter,
  [RenderCategory.ERC_ARROWS_FOR_SELECTED_ARMIES] = isShowPathForSelectedArmyFilter,
  [RenderCategory.ERC_BATTLES] = isShowBattlesFilter
}

return {
  setWWMapFilter = @(category, enabled) categoryFilter?[category].set(enabled)
  isShowZonesFilter
  isShowPathForSelectedArmyFilter
  isShowBattlesFilter
}