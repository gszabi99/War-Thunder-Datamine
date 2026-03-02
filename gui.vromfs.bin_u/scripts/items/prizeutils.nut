let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")


let wpIcons = [
  { value = 1000, icon = "battle_trophy1k" },
  { value = 5000, icon = "battle_trophy5k" },
  { value = 10000, icon = "battle_trophy10k" },
  { value = 50000, icon = "battle_trophy50k" },
  { value = 100000, icon = "battle_trophy100k" },
  { value = 1000000, icon = "battle_trophy1kk" },
]

function getWPIcon(wp) {
  local icon = ""
  foreach (v in wpIcons)
    if (wp >= v.value || icon == "")
      icon = v.icon
  return icon
}

function getFullWPIcon(wp) {
  return LayersIcon.getIconData(getWPIcon(wp), null, null, "reward_warpoints")
}


return {
  getFullWPIcon
  getWPIcon
}
