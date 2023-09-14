//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { reqUnlockByClient, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { get_gui_regional_blk } = require("blkGetters")

let function giveUnlocksAbTestOnce(abTestBlk) {
  let unlocksList = abTestBlk.unlocks
  let unlockId = unlocksList?[(::my_user_id_int64 % abTestBlk.divider).tostring()]
  if (!unlockId || isUnlockOpened(unlockId, UNLOCKABLE_ACHIEVEMENT))
    return

  for (local i = 0; i < unlocksList.paramCount(); i++)
    if (isUnlockOpened(unlocksList.getParamValue(i), UNLOCKABLE_ACHIEVEMENT))
      return

  reqUnlockByClient(unlockId)
}

let function checkUnlocksByAbTestList() {
  let abTestUnlocksListByUsersGroups = get_gui_regional_blk()?.abTestUnlocksListByUsersGroups
  if (!abTestUnlocksListByUsersGroups)
    return

  foreach (abTestBlk in (abTestUnlocksListByUsersGroups % "abTest"))
    giveUnlocksAbTestOnce(abTestBlk)
}

return checkUnlocksByAbTestList
