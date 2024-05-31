from "%scripts/dagui_natives.nut" import save_online_single_job, save_profile
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { blkFromPath } = require("%sqstd/datablock.nut")
let { find_in_array, isDataBlock } = require("%sqStdLibs/helpers/u.nut")
let string = require("%sqstd/string.nut")
let { get_last_skin, set_last_skin } = require("unitCustomization")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getDownloadableSkins } = require("%scripts/customization/downloadableDecorators.nut")
let { isGuid } = require("%scripts/guidParser.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { get_current_mission_info_cached, get_user_skins_blk } = require("blkGetters")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { getSkinId, DEFAULT_SKIN_NAME, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { isInFlight } = require("gameplayBinding")
let { isSkinBanned } = require("%scripts/customization/bannedSkins.nut")
let { USEROPT_USER_SKIN } = require("%scripts/options/optionsExtNames.nut")
let { TANK_CAMO_ROTATION_SLIDER_FACTOR } = require("%scripts/customization/customizationConsts.nut")
let { floor, round, abs } = require("%sqstd/math.nut")

let previewedLiveSkinIds = []
let approversUnitToPreviewLiveResource = Watched(null)

function getMissionLevelPath(unit) {
  let misBlk = isInFlight()
    ? get_current_mission_info_cached()
    : get_meta_mission_info_by_name(unit.testFlight)
  return misBlk?.level
}

function getTechnicsSkins(levelPath) {
  let levelBlk = blkFromPath($"{string.slice(levelPath, 0, -3)}blk")
  let technicsSkins = levelBlk?.technicsSkins
  return isDataBlock(technicsSkins)
    ? technicsSkins % "groundSkin"
    : []
}

function getBestSkinsList(unitName, isLockedAllowed) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return [DEFAULT_SKIN_NAME]

  let level = getMissionLevelPath(unit)
  if (!level)
    return [DEFAULT_SKIN_NAME]

  let skinsList = [DEFAULT_SKIN_NAME]
  foreach (skin in unit.getSkins()) {
    if (skin.name == "")
      continue
    if (isLockedAllowed) {
      skinsList.append(skin.name)
      continue
    }
    let decorator = getDecorator(getSkinId(unitName, skin.name), decoratorTypes.SKINS)
    if (decorator?.isUnlocked())
      skinsList.append(skin.name)
  }
  return skinLocations.getBestSkinsList(skinsList, unitName, level, decoratorTypes.SKINS)
}

// return default skin if no skin matches location
function getAutoSkin(unitName) {
  local list = getBestSkinsList(unitName, false)
    .filter(@(s) !isSkinBanned($"{unitName}/{s}"))
  if (list.len() == 0)
    return DEFAULT_SKIN_NAME
  // use last skin if no in session

  let couponSkins = list.filter(
    function(skin) {
      let decorator = getDecorator(getSkinId(unitName, skin), decoratorTypes.SKINS)
      return decorator?.getCouponItemdefId() != null
    }
  )

  if (couponSkins.len() > 0)
    list = couponSkins

  let levelPath = getMissionLevelPath(getAircraftByName(unitName))
  let technicsSkins = getTechnicsSkins(levelPath)

  foreach (skin in technicsSkins) {
    let locationTypeBit = skinLocations.getLocationTypeId(skin)
    foreach (unitSkin in list) {
      let skinLocationsMask = skinLocations.getSkinLocationsMask(unitSkin, unitName, decoratorTypes.SKINS)
      if ((skinLocationsMask & locationTypeBit) != 0)
        return unitSkin
    }
  }

  return list[list.len() - 1 - (::SessionLobby.getRoomId() % list.len())]
}

let getSkinSaveId = @(unitName) $"skins/{unitName}"

function isAutoSkinAvailable(unitName) {
  return unitTypes.getByUnitName(unitName).isSkinAutoSelectAvailable()
}

function getLastSkin(unitName) {
  let unit = getAircraftByName(unitName)
  if (!unit.isUsable() && unit.getPreviewSkinId() != "")
    return unit.getPreviewSkinId()
  if (!isAutoSkinAvailable(unitName))
    return get_last_skin(unitName)
  return loadLocalAccountSettings(getSkinSaveId(unitName))
}

function setLastSkin(unitName, skinName, needAutoSkin = true) {
  if (!isAutoSkinAvailable(unitName))
    return skinName && set_last_skin(unitName, skinName)
  if (needAutoSkin || getLastSkin(unitName))
    saveLocalAccountSettings(getSkinSaveId(unitName), skinName)
  if (!needAutoSkin || skinName)
    set_last_skin(unitName, skinName || getAutoSkin(unitName))
}

let isAutoSkinOn = @(unitName) !getLastSkin(unitName)
let getRealSkin  = @(unitName) getLastSkin(unitName) || getAutoSkin(unitName)

function setAutoSkin(unitName, needSwitchOn) {
  if (needSwitchOn != isAutoSkinOn(unitName))
    setLastSkin(unitName, needSwitchOn ? null : get_last_skin(unitName))
}

function setCurSkinToHangar(unitName) {
  if (!isAutoSkinOn(unitName))
    set_last_skin(unitName, getRealSkin(unitName))
}

function isPreviewingLiveSkin() {
  return hasFeature("EnableLiveSkins") && previewedLiveSkinIds.len() > 0
}

function addDownloadableLiveSkins(skins, unit) {
  let downloadableSkins = getDownloadableSkins(unit.name, decoratorTypes.SKINS)
  if (downloadableSkins.len() == 0)
    return skins

  skins = [].extend(skins)

  foreach (itemdefId in downloadableSkins) {
    let resource = ::ItemsManager.findItemById(itemdefId)?.getMetaResource()
    if (resource == null)
      continue

    if (isGuid(resource)) { // Live skin
      let foundIdx = skins.findindex(@(s) s?.name == resource)
      let skin = (foundIdx != null)
        ? skins.remove(foundIdx) // Removing to preserve order, because cached skins are already listed.
        : {
            name = resource
            nameLocId = ""
            descLocId = ""

            isDownloadable = true // Needs to be downloaded and cached.
          }
      skin.forceVisible <- true
      skins.append(skin)
    }
    else { // Internal skin
      let skinName = getSkinNameBySkinId(resource)
      let skin = skins.findvalue(@(s) s?.name == skinName)
      if (skin == null)
        continue
      skin.forceVisible <- true
    }
  }

  return skins
}

const COLORED_DROPRIGHT_TEXT_STYLE = "textStyle:t='textarea';"

function addSkinItemToOption(option, locName, value, decorator, shouldSetFirst = false, needIcon = false) {
  let idx = shouldSetFirst ? 0 : option.items.len()
  option.items.insert(idx, {
    text = locName
    textStyle = COLORED_DROPRIGHT_TEXT_STYLE
    image = needIcon ? decorator.getSmallIcon() : null
  })
  option.values.insert(idx, value)
  option.decorators.insert(idx, decorator)
  option.access.insert(idx, {
    isOwn          = true
    unlockId       = ""
    canBuy         = false
    price          = ::zero_money
    isVisible      = true
    isDownloadable = false
    isAutoSkin     = false
  })
  return option.access[idx]
}

function getSkinsOption(unitName, showLocked = false, needAutoSkin = true, showDownloadable = false) {
  let descr = {
    items      = []
    values     = []
    access     = []
    decorators = []
    autoSkin   = null
    value      = 0
  }

  let unit = getAircraftByName(unitName)
  if (!unit)
    return descr

  let needIcon = unit.esUnitType == ES_UNIT_TYPE_TANK

  local skins = unit.getSkins()
  if (showDownloadable)
    skins = addDownloadableLiveSkins(skins, unit)

  for (local skinNo = 0; skinNo < skins.len(); ++skinNo) {
    let skin = skins[skinNo]
    let isDefault = skin.name.len() == 0
    // skin ID (default skin stored in profile with name 'default')
    let skinName = isDefault ? DEFAULT_SKIN_NAME : skin.name
    let skinBlockName = getSkinId(unitName, skinName)
    let isPreviewedLiveSkin = hasFeature("EnableLiveSkins")
      && isInArray(skinBlockName, previewedLiveSkinIds)
    local decorator = getDecorator(skinBlockName, decoratorTypes.SKINS)
    if (!decorator) {
      if (isPreviewedLiveSkin)
        decorator = ::Decorator(skinBlockName, decoratorTypes.SKINS)
      else
        continue
    }

    let isUnlocked = decorator.isUnlocked()
    let isOwn = isDefault || isUnlocked
    if (!isOwn && !showLocked)
      continue

    let forceVisible = skin?.forceVisible || isPreviewedLiveSkin
    if (!decorator.isVisible() && !forceVisible)
      continue

    let cost = decorator.getCost()
    let hasPrice = !cost.isZero()
    let isVisible = isDefault || isOwn || hasPrice || forceVisible
      || decorator.canBuyCouponOnMarketplace(unit)
      || isUnlockVisible(decorator.unlockBlk)
    if (!isVisible && !is_dev_version())
      continue

    let access = addSkinItemToOption(descr, decorator.getName(), skinName, decorator, false, needIcon)
    access.isOwn          = isOwn
    access.unlockId       = !isOwn && decorator.unlockBlk ? decorator.unlockId : ""
    access.canBuy         = decorator.canBuyUnlock(unit)
    access.price          = cost
    access.isVisible      = isVisible
    access.isDownloadable = skin?.isDownloadable ?? false
    access.isAutoSkin     = false
  }

  let hasAutoSkin = needAutoSkin && isAutoSkinAvailable(unitName)
  if (hasAutoSkin) {
    let autoSkin = getAutoSkin(unitName)
    let decorator = getDecorator(getSkinId(unitName, autoSkin), decoratorTypes.SKINS)
    let locName = loc("skins/auto", { skin = (decorator?.getName() ?? "") })
    let access = addSkinItemToOption(descr, locName, null, decorator, true, needIcon)
    access.isAutoSkin = true
    descr.autoSkin = autoSkin
  }

  let curSkin = getLastSkin(unit.name)
  descr.value = find_in_array(descr.values, curSkin, -1)
  if (descr.value != -1 || !descr.values.len())
    return descr

  descr.value = 0
  if (curSkin && curSkin != "") // cur skin is not valid, need set valid skin
    setLastSkin(unit.name, descr.values[0], hasAutoSkin)

  return descr
}

let getCurUnitUserSkins = @() get_user_skins_blk()?[::cur_aircraft_name]

function getCurUserSkin() {
  let userSkins = getCurUnitUserSkins()
  if (userSkins == null)
    return null
  let opt = ::get_option(USEROPT_USER_SKIN)
  let curVal = opt.value
  let curUserSkinName = opt.values?[curVal] ?? ""
  return (userSkins % "skin").findvalue(@(s) s.name == curUserSkinName)
}

let getSkinConditionByPercent = @(val) 2 * val - 100
function getUserSkinCondition() {
  let { condition = null} = getCurUserSkin()
  if (condition == null)
    return null
  return getSkinConditionByPercent(condition)
}

function getSkinRotationByDeg(deg) {
  local estimatedVal = round(TANK_CAMO_ROTATION_SLIDER_FACTOR * abs(deg) * 100 / 180)
  let calculatedDegrees = floor(((estimatedVal * 180) / 100) / TANK_CAMO_ROTATION_SLIDER_FACTOR)

  if (calculatedDegrees < abs(deg))
    estimatedVal += 1
  else if (calculatedDegrees > abs(deg))
    estimatedVal -= 1

  return deg >= 0 ? estimatedVal : -estimatedVal
}

function getUserSkinRotation() {
  let { rotation = null} = getCurUserSkin()
  if (rotation == null)
    return null
  return getSkinRotationByDeg(rotation)
}

function getSkinScaleByRawPercent(val) {
  let minTankCamoScale = 0.2
  let maxTankCamoScale = 2
  let scaleRange = 10

  if (val < minTankCamoScale || val > maxTankCamoScale)
    return 0
  // сonvert percentage to a scale value ranging from -10 to +10
  if (val > 1)
    return ((val - 1.0) / (maxTankCamoScale - 1.0)) * scaleRange
  if (val < 1)
    return -(val - 1.0) / (minTankCamoScale - 1.0) * scaleRange
  return 0
}

function getUserSkinScale() {
  let { scale = null} = getCurUserSkin()
  if (scale == null)
    return null
  return getSkinScaleByRawPercent(scale)
}

function applyPreviewSkin(unitName) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return

  let previewSkinId = unit.getPreviewSkinId()
  if (previewSkinId == "")
    return

  setLastSkin(unit.name, previewSkinId, false)

  save_online_single_job(3210)
  save_profile(false)
}

function clearLivePreviewParams() {
  previewedLiveSkinIds.clear()
  approversUnitToPreviewLiveResource(null)
}

addListenersWithoutEnv({
  DecorCacheInvalidate = @(_) clearLivePreviewParams()
  LoginComplete = @(_) clearLivePreviewParams()
  SignOut = @(_) clearLivePreviewParams()
  UnitBought = @(p) applyPreviewSkin(p?.unitName)
  UnitRented = @(p) applyPreviewSkin(p?.unitName)
}, g_listener_priority.CONFIG_VALIDATION)

return {
  getAutoSkin
  setAutoSkin
  getLastSkin
  setLastSkin
  getRealSkin
  setCurSkinToHangar
  isAutoSkinOn
  isAutoSkinAvailable
  getSkinsOption
  getBestSkinsList
  clearLivePreviewParams
  isPreviewingLiveSkin
  previewedLiveSkinIds
  approversUnitToPreviewLiveResource
  getCurUnitUserSkins
  getCurUserSkin
  getUserSkinCondition
  getUserSkinRotation
  getUserSkinScale
}
