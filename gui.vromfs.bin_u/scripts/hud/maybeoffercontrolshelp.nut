let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")

enum ControlsHelpHintConditionType {
  ARACHIS_EVENT = 1,
  SUBMARINE = 2
}

let conditionTypeToCheckFn = {
  [ControlsHelpHintConditionType.ARACHIS_EVENT] = @() [
      "combat_track_a", "combat_track_h", "combat_tank_a", "combat_tank_h", "mlrs_tank_a",
      "mlrs_tank_h", "acoustic_heavy_tank_a", "destroyer_heavy_tank_h","dragonfly_a", "dragonfly_h"
    ].contains(getPlayerCurUnit()?.name),
  [ControlsHelpHintConditionType.SUBMARINE] = @() !!getPlayerCurUnit()?.isSubmarine()
}

return function maybeOfferControlsHelp() {
  local curConditionType = null
  foreach (condType, checkFn in conditionTypeToCheckFn)
    if (checkFn()) {
      curConditionType = condType
      break
    }

  if (curConditionType != null)
    ::g_hud_event_manager.onHudEvent("hint:f1_controls_scripted:show", { conditionSeenCountType = curConditionType })
}