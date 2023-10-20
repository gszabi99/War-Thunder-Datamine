//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
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
let { get_current_mission_info_cached  } = require("blkGetters")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { getSkinId, DEFAULT_SKIN_NAME, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { isInFlight } = require("gameplayBinding")

let previewedLiveSkinIds = []
let approversUnitToPreviewLiveResource = Watched(null)

let function getBestSkinsList(unitName, isLockedAllowed) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return [DEFAULT_SKIN_NAME]

  let misBlk = isInFlight()
    ? get_current_mission_info_cached()
    : get_meta_mission_info_by_name(unit.testFlight)
  let level = misBlk?.level
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
let function getAutoSkin(unitName, isLockedAllowed = false) {
  let list = getBestSkinsList(unitName, isLockedAllowed)
  if (list.len() == 0)
    return DEFAULT_SKIN_NAME
  // use last skin if no in session
  return list[list.len() - 1 - (::SessionLobby.roomId % list.len())]
}

let getSkinSaveId = @(unitName) $"skins/{unitName}"

let function isAutoSkinAvailable(unitName) {
  return unitTypes.getByUnitName(unitName).isSkinAutoSelectAvailable()
}

let function getLastSkin(unitName) {
  let unit = getAircraftByName(unitName)
  if (!unit.isUsable() && unit.getPreviewSkinId() != "")
    return unit.getPreviewSkinId()
  if (!isAutoSkinAvailable(unitName))
    return get_last_skin(unitName)
  return loadLocalAccountSettings(getSkinSaveId(unitName))
}

let function setLastSkin(unitName, skinName, needAutoSkin = true) {
  if (!isAutoSkinAvailable(unitName))
    return skinName && set_last_skin(unitName, skinName)
  if (needAutoSkin || getLastSkin(unitName))
    saveLocalAccountSettings(getSkinSaveId(unitName), skinName)
  if (!needAutoSkin || skinName)
    set_last_skin(unitName, skinName || getAutoSkin(unitName))
}

let isAutoSkinOn = @(unitName) !getLastSkin(unitName)
let getRealSkin  = @(unitName) getLastSkin(unitName) || getAutoSkin(unitName)

let function setAutoSkin(unitName, needSwitchOn) {
  if (needSwitchOn != isAutoSkinOn(unitName))
    setLastSkin(unitName, needSwitchOn ? null : get_last_skin(unitName))
}

let function setCurSkinToHangar(unitName) {
  if (!isAutoSkinOn(unitName))
    set_last_skin(unitName, getRealSkin(unitName))
}

let function isPreviewingLiveSkin() {
  return hasFeature("EnableLiveSkins") && previewedLiveSkinIds.len() > 0
}

let function addDownloadableLiveSkins(skins, unit) {
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

let function addSkinItemToOption(option, locName, value, decorator, shouldSetFirst = false, needIcon = false) {
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
  })
  return option.access[idx]
}

let function getSkinsOption(unitName, showLocked = false, needAutoSkin = true, showDownloadable = false) {
  let descr = {
    items      = []
    values     = []
    access     = []
    decorators = []
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
    if (!isVisible && !::is_dev_version)
      continue

    let access = addSkinItemToOption(descr, decorator.getName(), skinName, decorator, false, needIcon)
    access.isOwn          = isOwn
    access.unlockId       = !isOwn && decorator.unlockBlk ? decorator.unlockId : ""
    access.canBuy         = decorator.canBuyUnlock(unit)
    access.price          = cost
    access.isVisible      = isVisible
    access.isDownloadable = skin?.isDownloadable ?? false
  }

  let hasAutoSkin = needAutoSkin && isAutoSkinAvailable(unitName)
  if (hasAutoSkin) {
    let autoSkin = getAutoSkin(unitName)
    let decorator = getDecorator(getSkinId(unitName, autoSkin), decoratorTypes.SKINS)
    let locName = loc("skins/auto", { skin = (decorator?.getName() ?? "") })
    addSkinItemToOption(descr, locName, null, decorator, true, needIcon)
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

let function applyPreviewSkin(unitName) {
  let unit = getAircraftByName(unitName)
  if (!unit)
    return

  let previewSkinId = unit.getPreviewSkinId()
  if (previewSkinId == "")
    return

  setLastSkin(unit.name, previewSkinId, false)

  ::save_online_single_job(3210)
  ::save_profile(false)
}

let function clearLivePreviewParams() {
  previewedLiveSkinIds.clear()
  approversUnitToPreviewLiveResource(null)
}

addListenersWithoutEnv({
  DecorCacheInvalidate = @(_) clearLivePreviewParams()
  LoginComplete = @(_) clearLivePreviewParams()
  SignOut = @(_) clearLivePreviewParams()
  UnitBought = @(p) applyPreviewSkin(p?.unitName)
  UnitRented = @(p) applyPreviewSkin(p?.unitName)
}, ::g_listener_priority.CONFIG_VALIDATION)

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
}




