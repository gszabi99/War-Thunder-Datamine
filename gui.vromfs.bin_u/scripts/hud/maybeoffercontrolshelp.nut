let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { isMissionExtr } = require("%scripts/missions/missionsUtils.nut")

enum ControlsHelpHintConditionType {
  ARACHIS_EVENT = 1,
  SUBMARINE = 2,
  EXTR_EVENT = 3,
}

let conditionTypeToCheckFn = {
  [ControlsHelpHintConditionType.ARACHIS_EVENT] = @() [
      "combat_track_a", "combat_track_h", "combat_tank_a", "combat_tank_h", "mlrs_tank_a",
      "mlrs_tank_h", "acoustic_heavy_tank_a", "destroyer_heavy_tank_h","dragonfly_a", "dragonfly_h"
    ].contains(getPlayerCurUnit()?.name),
  [ControlsHelpHintConditionType.SUBMARINE] = @() !!getPlayerCurUnit()?.isSubmarine(),
  [ControlsHelpHintConditionType.EXTR_EVENT] = @() isMissionExtr(),
}

function getEventConditionControlHelp() {
  foreach (condType, checkFn in conditionTypeToCheckFn)
    if (checkFn())
      return condType

  return null
}

function maybeOfferControlsHelp() {
  let conditionSeenCountType = getEventConditionControlHelp()
  if (conditionSeenCountType != null)
    g_hud_event_manager.onHudEvent("hint:f1_controls_scripted:show", { conditionSeenCountType })
}

return {
  maybeOfferControlsHelp
  getEventConditionControlHelp
}
