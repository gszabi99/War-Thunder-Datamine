from "%scripts/dagui_library.nut" import *
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

let bannedSkins = hardPersistWatched("bannedSkins", [])

let loadBannedSkins = @() bannedSkins.set(loadLocalAccountSettings("bannedSkins", "").split())

let saveBannedSkins = @() saveLocalAccountSettings("bannedSkins", " ".join(bannedSkins.get()))

let isSkinBanned = @(skinId) bannedSkins.get().indexof(skinId) != null

let addSkinToBanned = @(skinId) bannedSkins.mutate(@(v) v.append(skinId))

function removeSkinFromBanned(skinId) {
  let index = bannedSkins.get().indexof(skinId)
  if(index != null)
    bannedSkins.mutate(@(v) v.remove(index))
}

addListenersWithoutEnv({
  LoginComplete = @(_p) loadBannedSkins()
})

return {
  saveBannedSkins
  isSkinBanned
  addSkinToBanned
  removeSkinFromBanned
}