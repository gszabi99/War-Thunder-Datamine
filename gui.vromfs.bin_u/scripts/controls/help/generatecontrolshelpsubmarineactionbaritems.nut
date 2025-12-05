let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { EII_TORPEDO, EII_MINE, EII_REPAIR_BREACHES, EII_EXTINGUISHER,
  EII_PERISCOPE
} = require("hudActionBarConst")

return function generateSubmarineActionBars(actionBarsCount = 1) {
  let actionBars = []
  for (local i = 1; i <= actionBarsCount; i++) {
    actionBars.append({
      nest  = $"action_bar_place_{i}"
      hudUnitType = HUD_UNIT_TYPE.SHIP
      items = [
        {
          type = EII_TORPEDO
          active = true
          id = $"bar_item_torpedo_{i}"
          selected = true
        }
        {
          type = EII_MINE
          id = $"bar_item_mine_{i}"
        }
        {
          type = EII_REPAIR_BREACHES
          id = $"bar_item_repair_breaches_{i}"
        }
        {
          type = EII_EXTINGUISHER
          id = $"bar_item_extinguisher_{i}"
        }
        {
          type = EII_PERISCOPE
          id = $"bar_item_periscope_{i}"
        }
      ]
    })
  }

  return actionBars
}