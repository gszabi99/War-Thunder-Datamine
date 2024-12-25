from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { utf8ToLower} = require("%sqstd/string.nut")
let { addTask } = require("%scripts/tasker.nut")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { setUserInfoParams } = require("%scripts/user/usersInfoManager.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")

local profileHeaderBackgrounds = null
local profileAvatarFrames = null

function getProfileHeaderBackgrounds() {
  if (profileHeaderBackgrounds != null)
    return profileHeaderBackgrounds

  profileHeaderBackgrounds = getUnlocksByTypeInBlkOrder("background")
    .filter(@(unlock) isUnlockVisible(unlock) || isUnlockOpened(unlock.id))
    .map(function(unlock) {
      let locName = loc($"{unlock.id}/name")
      return {
        id = unlock.id
        headerName = locName
        searchName = utf8ToLower(locName)
      }
    })

  return profileHeaderBackgrounds
}

function getProfileAvatarFrames() {
  if (profileAvatarFrames != null)
    return profileAvatarFrames

  profileAvatarFrames = getUnlocksByTypeInBlkOrder("frame")
    .filter(@(unlock) isUnlockVisible(unlock) || isUnlockOpened(unlock.id))
    .map(@(unlock) {
      id = unlock.id
      unlockId = unlock.id
      enabled = true
      image = $"!ui/images/avatar_frames/{unlock.id}.avif"
      tooltip = loc($"{unlock.id}/name")
    })

  profileAvatarFrames.insert(0, {
    id = ""
    unlockId = ""
    enabled = true
    image = ""
    tooltip = loc("profile/no_frame")
  })

  return profileAvatarFrames
}

function saveProfileAppearance(params, cbSuccess = null, cbError = null) {
  let userId = userIdStr.get()
  function successCb() {
    setUserInfoParams(userId, params)
    cbSuccess?()
  }

  let requestBlk = params.reduce(function(res, image, imageType) {
    res[imageType] = image
    return res
  }, DataBlock())

  let taskId = char_send_blk("cln_save_pilot_appearance", requestBlk)
  addTask(taskId, {}, successCb, cbError)
}

function invalidateCache(_) {
  profileHeaderBackgrounds = null
  profileAvatarFrames = null
}

addListenersWithoutEnv({
  ProfileUpdated = invalidateCache,
  GameLocalizationChanged = @(_) profileHeaderBackgrounds = null
}, CONFIG_VALIDATION)

return {
  getProfileHeaderBackgrounds
  getProfileAvatarFrames
  saveProfileAppearance
}
