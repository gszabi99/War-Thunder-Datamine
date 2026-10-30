from "frp" import Watched
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%scripts/user/features.nut" import hasFeature
from "%appGlobals/ranks_common_shared.nut" import calcBattleRatingFromRank
from "%scripts/dagui_natives.nut" import get_unit_mrank_delta, char_send_blk
from "%scripts/tasker.nut" import addTask
from "chardResearch" import shopIsModificationPurchased
import "DataBlock" as DataBlock

let selectedAddMrankByUnitName = Watched({})

function getSelectableAddMranks(unit) {
  let deltas = [0]
  foreach (mod in unit.getModifications()) {
    let addMrank = mod.addMrank
    if (addMrank <= 0 || !shopIsModificationPurchased(unit.name, mod.name))
      continue
    if (!deltas.contains(addMrank))
      deltas.append(addMrank)
  }
  return deltas
}

function hasBoughtAddMrankMod(unit) {
  return getSelectableAddMranks(unit).len() > 1
}

function hasAnyAddMrankMod(unit) {
  foreach (mod in unit.getModifications())
    if (mod.addMrank > 0)
      return true
  return false
}

function isUnitMrankLockAvailable(unit) {
  return hasFeature("SelectableBattleRating") && hasBoughtAddMrankMod(unit)
}

function isMrankLockableItem(item) {
  return (item?.addMrank ?? 0) > 0
}

function persistUnitSelectedAddMrank(unitName, addMrank, onError) {
  let blk = DataBlock()
  blk.addStr("unit", unitName)
  blk.addInt("addMrank", addMrank)
  let taskId = char_send_blk("cln_set_unit_selected_mrank", blk)
  if (!addTask(taskId, { showProgressBox = true, showErrorMessageBox = false }, null, onError))
    onError?()
}

function setSelectedUnitAddMrank(unitName, addMrank) {
  selectedAddMrankByUnitName.mutate(@(t) t[unitName] <- addMrank)
}

function resetSelectedUnitAddMrank(unitName) {
  if (selectedAddMrankByUnitName.get()?[unitName] == null)
    return
  selectedAddMrankByUnitName.mutate(@(t) t.$rawdelete(unitName))
}

function getEffectiveMrankDelta(unit) {
  let delta = get_unit_mrank_delta(unit.name)
  return delta >= 0 ? delta : 0
}

function getEffectiveMrank(unit, ediff, mrankDelta = null) {
  return unit.getEconomicRank(ediff) + (mrankDelta ?? getEffectiveMrankDelta(unit))
}

function getMrankDeltaByUnit(unitNames) {
  let res = {}
  foreach (unitName in unitNames) {
    let delta = get_unit_mrank_delta(unitName)
    if (delta > 0)
      res[unitName] <- delta
  }
  return res
}

function getMrankComboDelta(unit) {
  return selectedAddMrankByUnitName.get()?[unit.name] ?? getEffectiveMrankDelta(unit)
}

function getUnitSelectedBattleRating(unit, ediff) {
  if (!hasFeature("SelectableBattleRating"))
    return unit.getBattleRating(ediff)
  return calcBattleRatingFromRank(getEffectiveMrank(unit, ediff))
}

addListenersWithoutEnv({
  SignOut = @(_p) selectedAddMrankByUnitName.set({})
  ProfileUpdated = function(_p) {
    let draft = selectedAddMrankByUnitName.get()
    let confirmedUnits = []
    foreach (unitName, addMrank in draft)
      if (get_unit_mrank_delta(unitName) == addMrank)
        confirmedUnits.append(unitName)
    if (confirmedUnits.len() == 0)
      return
    selectedAddMrankByUnitName.mutate(function(t) {
      foreach (unitName in confirmedUnits)
        t.$rawdelete(unitName)
    })
    foreach (unitName in confirmedUnits)
      broadcastEvent("UnitMrankSelectionChanged", { unitName })
  }
})

return freeze({
  setSelectedUnitAddMrank
  resetSelectedUnitAddMrank
  persistUnitSelectedAddMrank
  hasAnyAddMrankMod
  getSelectableAddMranks
  getEffectiveMrankDelta
  getEffectiveMrank
  getMrankDeltaByUnit
  getMrankComboDelta
  isUnitMrankLockAvailable
  isMrankLockableItem
  getUnitSelectedBattleRating
})
