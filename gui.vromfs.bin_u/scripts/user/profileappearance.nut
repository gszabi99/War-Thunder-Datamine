import "%scripts/user/avatars.nut" as avatars
import "DataBlock" as DataBlock
import "%appGlobals/config/animatedFrames.nut" as animatedFrames
from "%scripts/crossModuleEvents.nut" import GAME_LOCALIZATION_CHANGED
from "%scripts/tasker.nut" import addTask
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible, isUnlockOpened
from "%scripts/unlocks/unlocksCache.nut" import getUnlocksByTypeInBlkOrder
from "%scripts/user/usersInfoManager.nut" import setUserInfoParams
from "%scripts/user/profileStates.nut" import userIdStr
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "string" import format
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv, CONFIG_VALIDATION
from "%sqstd/string.nut" import utf8ToLower
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

const ANIMATED_FRAME_PREFIX = "anim_frame_"

local profileHeaderBackgrounds = null
local profileAvatarFrames = null

let avatarFramesPathCache = {}

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

let mkAnimFrameImagePath = @(name) $"!#ui/images/avatar_frames/{name}/{name}_%03d.avif"

let mkFrameImagePath = @(name) $"!ui/images/avatar_frames/{name}.avif"

let emptyAvatarFrameCfg = {
  frameImagePath = null
  framesCount = null
}

function getProfileAvatarFrameCfg(frame) {
  if (frame in avatarFramesPathCache)
    return avatarFramesPathCache[frame]

  if (frame == "")
    return emptyAvatarFrameCfg

  let pathConfig = {
    frameImagePath = ""
    framesCount = null
  }
  avatarFramesPathCache[frame] <- pathConfig
  if (frame in animatedFrames) {
    pathConfig.frameImagePath = mkAnimFrameImagePath(frame)
    pathConfig.framesCount = animatedFrames[frame]
    return pathConfig
  }

  let isAnimatedFrame = frame.startswith(ANIMATED_FRAME_PREFIX)
  if (isAnimatedFrame)
    logerr($"ANIMATED_FRAME: Frame config for /*frameId = {frame}*/ not found. Need add it to 'wt/globals/config/animatedFrames.nut' file")

  pathConfig.frameImagePath = isAnimatedFrame ? format(mkAnimFrameImagePath(frame), 0) 
    : mkFrameImagePath(frame)
  return pathConfig
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
    let { frameImagePath, framesCount } = getProfileAvatarFrameCfg(unlock.id)
    profileAvatarFrames.append({
      id = unlock.id
      unlockId = unlock.id
      enabled = isOpened
      image = frameImagePath
      framesCount
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
  [GAME_LOCALIZATION_CHANGED] = @(_) profileHeaderBackgrounds = null
}, CONFIG_VALIDATION)

return freeze({
  getProfileHeaderBackgrounds
  getProfileAvatarFrames
  getProfileAvatars
  getProfileAvatarFrameCfg

  saveProfileAppearance
})
