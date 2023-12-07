from "%scripts/dagui_library.nut" import *

let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let { isUnitInSlotbar } = require("%scripts/slotbar/slotbarState.nut")

let function takeUnitInSlotbar(unit, params = {}) {
  if (!unit)
    return

  ::queues.checkAndStart(
    function() {
      checkSquadUnreadyAndDo(
        function () {
          if (!unit || !unit.isUsable() || isUnitInSlotbar(unit))
            return

          ::gui_start_selecting_crew({
            unit = unit
          }.__update(params))
        }, null, params?.shouldCheckCrewsReady ?? false)
    },
    null, "isCanModifyCrew", null)
}

return takeUnitInSlotbar
