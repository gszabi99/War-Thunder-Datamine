from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let DataBlock = require("DataBlock")
let { broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { utf8ToLower} = require("%sqstd/string.nut")
let { addTask } = require("%scripts/tasker.nut")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlocksByTypeInBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { setUserInfoParams } = require("%scripts/user/usersInfoManager.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let avatars = require("%scripts/user/avatars.nut")

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

  profileAvatarFrames = []
  let frames = getUnlocksByTypeInBlkOrder("frame")
  foreach (unlock in frames) {
    let isVisible = isUnlockVisible(unlock)
    let isOpened = isUnlockOpened(unlock.id)
    if (!isVisible && !isOpened)
      continue
    profileAvatarFrames.append({
      id = unlock.id
      unlockId = unlock.id
      enabled = isOpened
      image = $"!ui/images/avatar_frames/{unlock.id}.avif"
      tooltipId = getTooltipType("UNLOCK").getTooltipId(unlock.id, { showProgress = true, tooltipImageSize = "1@avatarButtonSize, 1@avatarButtonSize" })
    })
  }

  profileAvatarFrames.insert(0, {
    id = ""
    unlockId = ""
    enabled = true
    image = ""
    tooltip = loc("profile/no_frame")
  })

  return profileAvatarFrames
}

function getProfileAvatars() {
  let items = []
  let icons = avatars.getIcons(true)
  let marketplaceItemdefIds = []
  for (local i = 0; i < icons.len(); i++) {
    let unlockItem = icons[i]
    let unlockId = icons[i].id
    let marketplaceItemdefId = unlockItem?.marketplaceItemdefId
    if (marketplaceItemdefId != null)
      marketplaceItemdefIds.append(marketplaceItemdefId)

    let isItemEnabled = isUnlockOpened(unlockId, UNLOCKABLE_PILOT)
    let isItemVisible = isItemEnabled || isUnlockVisible(unlockItem)
    if (!isItemVisible)
      continue
    let item = {
      idx = i
      unlockId
      image = $"#ui/images/avatars/{unlockId}.avif"
      enabled = isItemEnabled
      tooltipId = getTooltipType("UNLOCK").getTooltipId(unlockId, { showProgress = true, tooltipImageSize = "1@avatarButtonSize, 1@avatarButtonSize" })
      marketplaceItemdefId
    }
    if (isItemEnabled) {
      item.seenListId <- SEEN.AVATARS
      item.seenEntity <- unlockId
    }
    items.append(item)

  }
  if (marketplaceItemdefIds.len() > 0)
    inventoryClient.requestItemdefsByIds(marketplaceItemdefIds)

  return items
}

function saveProfileAppearance(params, cbSuccess = null, cbError = null) {
  let userId = userIdStr.get()
  function successCb() {
    setUserInfoParams(userId, params)
    broadcastEvent("AvatarChanged")
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
  getProfileAvatars

  saveProfileAppearance
}
