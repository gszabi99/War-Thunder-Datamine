from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/customization/skinUtils.nut" import DEFAULT_SKIN_NAME, getPlaneBySkinId, getSkinNameBySkinId
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%sqstd/globalState.nut" import hardPersistWatched
from "%scripts/dagui_library.nut" import *

let prioritySkins = hardPersistWatched("prioritySkins", {})

function loadPrioritySkins() {
  let prioritySkinsByUnit = loadLocalAccountSettings("prioritySkins", "")
  .split()
  .reduce(function(res, val) {
    res[getPlaneBySkinId(val)] <- getSkinNameBySkinId(val)
    return res
  }, {})
  prioritySkins.set(prioritySkinsByUnit)
}

function savePrioritySkins() {
  let skinsData = prioritySkins.get().reduce(function(res, val, key) {
    res.append($"{key}/{val}")
    return res
  }, [])
  saveLocalAccountSettings("prioritySkins", " ".join(skinsData))
}

function removePrioritySkin(unitName) {
  prioritySkins.mutate(@(v) v.$rawdelete(unitName))
  savePrioritySkins()
}

let getPrioritySkin = @(unitName) prioritySkins.get()?[unitName]

function setPrioritySkin(unitName, skinId) {
  if (skinId == DEFAULT_SKIN_NAME || getPrioritySkin(unitName) == skinId) {
    removePrioritySkin(unitName)
    return
  }

  prioritySkins.mutate(@(v) v[unitName] <- skinId)
  savePrioritySkins()
}

let isPrioritySkin = @(unitName, skinId) prioritySkins.get()?[unitName] == skinId
let hasPrioritySkin = @(unitName) unitName in prioritySkins.get()

addListenersWithoutEnv({
  LoginComplete = @(_p) loadPrioritySkins()
})

return freeze({
  isPrioritySkin
  hasPrioritySkin
  setPrioritySkin
  getPrioritySkin
})
