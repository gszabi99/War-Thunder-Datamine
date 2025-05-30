from "%scripts/dagui_library.nut" import *

let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")

let guiStartSelectingCrew = require("%scripts/slotbar/guiStartSelectingCrew.nut")

function takeUnitInSlotbar(unit, params = {}) {
  if (!unit)
    return

  checkQueueAndStart(
    function() {
      checkSquadUnreadyAndDo(
        function () {
          if (!unit || !unit.isUsable() || (isUnitInSlotbar(unit) && !params?.dragAndDropMode))
            return

          guiStartSelectingCrew({
            unit = unit
          }.__update(params))
        }, null, params?.shouldCheckCrewsReady ?? false)
    },
    null, "isCanModifyCrew", null)
}

return takeUnitInSlotbar
