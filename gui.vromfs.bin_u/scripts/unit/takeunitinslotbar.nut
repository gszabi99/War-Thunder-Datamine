import "%scripts/slotbar/guiStartSelectingCrew.nut" as guiStartSelectingCrew
from "%scripts/squads/squadUtils.nut" import checkSquadUnreadyAndDo
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitInSlotbar
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "%scripts/dagui_library.nut" import *

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
