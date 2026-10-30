from "%scripts/unlocks/unlocksModule.nut" import reqUnlockByClient, isUnlockOpened
from "%scripts/user/profileStates.nut" import userIdInt64
from "blkGetters" import get_gui_regional_blk
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_library.nut" import *

function giveUnlocksAbTestOnce(abTestBlk) {
  let unlocksList = abTestBlk.unlocks
  let unlockId = unlocksList?[(userIdInt64.get() % abTestBlk.divider).tostring()]
  if (!unlockId || isUnlockOpened(unlockId, UNLOCKABLE_ACHIEVEMENT))
    return

  for (local i = 0; i < unlocksList.paramCount(); i++)
    if (isUnlockOpened(unlocksList.getParamValue(i), UNLOCKABLE_ACHIEVEMENT))
      return

  reqUnlockByClient(unlockId)
}

function checkUnlocksByAbTestList() {
  let abTestUnlocksListByUsersGroups = get_gui_regional_blk()?.abTestUnlocksListByUsersGroups
  if (!abTestUnlocksListByUsersGroups)
    return

  foreach (abTestBlk in (abTestUnlocksListByUsersGroups % "abTest"))
    giveUnlocksAbTestOnce(abTestBlk)
}

return checkUnlocksByAbTestList
