let skinLocations = require("%scripts/customization/skinLocations.nut")
let guidParser = require("%scripts/guidParser.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getDownloadableSkins } = require("%scripts/customization/downloadableDecorators.nut")

const DEFAULT_SKIN_NAME = "default"

//code callback
::on_dl_content_skins_invalidate <- function on_dl_content_skins_invalidate()
{
  ::g_decorator.clearCache()
}

//code callback
::update_unit_skins_list <- function update_unit_skins_list(unitName)
{
  let unit = ::getAircraftByName(unitName)
  if (unit)
    unit.resetSkins()
}

::g_decorator <- {
  cache = {}
  liveDecoratorsCache = {}
  previewedLiveSkinIds = []
  approversUnitToPreviewLiveResource = null

  waitingItemdefs = {}

  addDownloadableLiveSkins = function(skins, unit)
  {
    let downloadableSkins = getDownloadableSkins(unit)
    if (downloadableSkins.len() == 0)
      return skins

    skins = [].extend(skins)

    foreach (itemdefId in downloadableSkins)
    {
      let resource = ::ItemsManager.findItemById(itemdefId)?.getMetaResource()
      if (resource == null)
        continue

      if (guidParser.isGuid(resource)) // Live skin
      {
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
      else // Internal skin
      {
        let skinName = ::g_unlocks.getSkinNameBySkinId(resource)
        let skin = skins.findvalue(@(s) s?.name == skinName)
        if (skin == null)
          continue
        skin.forceVisible <- true
      }
    }

    return skins
  }
}

g_decorator.clearCache <- function clearCache()
{
  ::g_decorator.cache.clear()
  ::g_decorator.clearLivePreviewParams()
}

g_decorator.clearLivePreviewParams <- function clearLivePreviewParams()
{
  ::g_decorator.previewedLiveSkinIds.clear()
  ::g_decorator.approversUnitToPreviewLiveResource = null
}

g_decorator.getCachedDataByType <- function getCachedDataByType(decType, unitType = null)
{
  let id = unitType ? $"proceedData_{decType.name}_{unitType}" : $"proceedData_{decType.name}"
  if (id in ::g_decorator.cache)
    return ::g_decorator.cache[id]

  let data = ::g_decorator.splitDecoratorData(decType, unitType)
  ::g_decorator.cache[id] <- data
  return data
}

g_decorator.getCachedDecoratorsDataByType <- function getCachedDecoratorsDataByType(decType, unitType = null)
{
  let data = ::g_decorator.getCachedDataByType(decType, unitType)
  return data.decorators
}

g_decorator.getCachedOrderByType <- function getCachedOrderByType(decType, unitType = null)
{
  let data = ::g_decorator.getCachedDataByType(decType, unitType)
  return data.categories
}

g_decorator.getCachedDecoratorsListByType <- function getCachedDecoratorsListByType(decType)
{
  let data = ::g_decorator.getCachedDataByType(decType)
  return data.decoratorsList
}

g_decorator.getDecorator <- function getDecorator(searchId, decType)
{
  local res = null
  if (::u.isEmpty(searchId))
    return res

  res = decType.getSpecialDecorator(searchId)
    || ::g_decorator.getCachedDecoratorsListByType(decType)?[searchId]
    || decType.getLiveDecorator(searchId, liveDecoratorsCache)
  if (!res)
    ::dagor.debug("Decorators Manager: " + searchId + " was not found in old cache, try update cache")
  return res
}

g_decorator.getDecoratorById <- function getDecoratorById(searchId)
{
  if (::u.isEmpty(searchId))
    return null

  foreach (t in ::g_decorator_type.types)
  {
    let res = getDecorator(searchId, t)
    if (res)
      return res
  }

  return null
}

g_decorator.getDecoratorByResource <- function getDecoratorByResource(resource, resourceType)
{
  return getDecorator(resource, ::g_decorator_type.getTypeByResourceType(resourceType))
}

g_decorator.getCachedDecoratorByUnlockId <- function getCachedDecoratorByUnlockId(unlockId, decType)
{
  if (::u.isEmpty(unlockId))
    return null

  let path = "decoratorByUnlockId"
  if (!(path in ::g_decorator.cache))
    ::g_decorator.cache[path] <- {}

  if (unlockId in ::g_decorator.cache[path])
    return getDecorator(::g_decorator.cache[path][unlockId], decType)

  let foundDecorator = ::u.search(::g_decorator.getCachedDecoratorsListByType(decType),
      (@(unlockId) function(d) {
        return d.unlockId == unlockId
      })(unlockId))

  if (foundDecorator == null)
    return null

  ::g_decorator.cache[path][unlockId] <- foundDecorator.id
  return foundDecorator
}

g_decorator.splitDecoratorData <- function splitDecoratorData(decType, unitType)
{
  let result = {
    decorators = {}
    categories = []
    decoratorsList = {}
    fullBlk = null
  }

  let blk = decType.getBlk()
  if (::u.isEmpty(blk))
    return result

  result.fullBlk = blk

  let prevCategory = ""
  for (local c = 0; c < blk.blockCount(); c++)
  {
    let dblk = blk.getBlock(c)

    let decorator = ::Decorator(dblk, decType)
    if (unitType != null && !decorator.isAllowedByUnitTypes(unitType))
      continue

    let category = dblk?.category ?? prevCategory

    if (!(category in result.decorators))
    {
      result.categories.append(category)
      result.decorators[category] <- []
    }

    decorator.category = category
    decorator.catIndex = result.decorators[category].len()

    if (decorator.getCouponItemdefId() != null && !::ItemsManager.findItemById(decorator.getCouponItemdefId()))
      waitingItemdefs[decorator.getCouponItemdefId()] <- decorator

    result.decoratorsList[decorator.id] <- decorator
    if (decorator.isVisible() || decorator.isForceVisible())
      result.decorators[category].append(decorator)
  }

  for (local i = result.categories.len() - 1; i > -1; i--)
  {
    let category = result.categories[i]
    let decoratorsList = result.decorators[category]
    if (decoratorsList.len() == 0)
    {
      result.categories.remove(i)
      delete result.decorators[category]
    }
  }

  return result
}

g_decorator.getSkinSaveId <- function getSkinSaveId(unitName)
{
  return "skins/" + unitName
}

g_decorator.isAutoSkinAvailable <- function isAutoSkinAvailable(unitName)
{
  return unitTypes.getByUnitName(unitName).isSkinAutoSelectAvailable()
}

g_decorator.getLastSkin <- function getLastSkin(unitName)
{
  let unit = getAircraftByName(unitName)
  if (!unit.isUsable() && unit.getPreviewSkinId() != "")
    return unit.getPreviewSkinId()
  if (!isAutoSkinAvailable(unitName))
    return ::hangar_get_last_skin(unitName)
  return ::load_local_account_settings(getSkinSaveId(unitName))
}

::g_decorator.isAutoSkinOn <- @(unitName) !getLastSkin(unitName)

g_decorator.getRealSkin <- function getRealSkin(unitName)
{
  let res = getLastSkin(unitName)
  return res || getAutoSkin(unitName)
}

g_decorator.setLastSkin <- function setLastSkin(unitName, skinName, needAutoSkin = true)
{
  if (!isAutoSkinAvailable(unitName))
    return skinName && ::hangar_set_last_skin(unitName, skinName)

  if (needAutoSkin || getLastSkin(unitName))
    ::save_local_account_settings(getSkinSaveId(unitName), skinName)
  if (!needAutoSkin || skinName)
    ::hangar_set_last_skin(unitName, skinName || getAutoSkin(unitName))
}

g_decorator.setCurSkinToHangar <- function setCurSkinToHangar(unitName)
{
  if (!isAutoSkinOn(unitName))
    ::hangar_set_last_skin(unitName, getRealSkin(unitName))
}

g_decorator.setAutoSkin <- function setAutoSkin(unitName, needSwitchOn)
{
  if (needSwitchOn != isAutoSkinOn(unitName))
    setLastSkin(unitName, needSwitchOn ? null : ::hangar_get_last_skin(unitName))
}

//default skin will return when no one skin match location
g_decorator.getAutoSkin <- function getAutoSkin(unitName, isLockedAllowed = false)
{
  let list = getBestSkinsList(unitName, isLockedAllowed)
  if (!list.len())
    return DEFAULT_SKIN_NAME
  return list[list.len() - 1 - (::SessionLobby.roomId % list.len())] //use last skin when no in session
}

g_decorator.getBestSkinsList <- function getBestSkinsList(unitName, isLockedAllowed)
{
  let unit = ::getAircraftByName(unitName)
  if (!unit)
    return [DEFAULT_SKIN_NAME]

  let misBlk = ::is_in_flight() ? ::get_current_mission_info_cached()
    : ::get_mission_meta_info(unit.testFlight)
  let level = misBlk?.level
  if (!level)
    return [DEFAULT_SKIN_NAME]

  let skinsList = [DEFAULT_SKIN_NAME]
  foreach(skin in unit.getSkins())
  {
    if (skin.name == "")
      continue
    if (isLockedAllowed)
    {
      skinsList.append(skin.name)
      continue
    }
    let decorator = ::g_decorator.getDecorator(unitName + "/"+ skin.name, ::g_decorator_type.SKINS)
    if (decorator && decorator.isUnlocked())
      skinsList.append(skin.name)
  }
  return skinLocations.getBestSkinsList(skinsList, unitName, level)
}

g_decorator.addSkinItemToOption <- function addSkinItemToOption(option, locName, value, decorator, shouldSetFirst = false, needIcon = false)
{
  let idx = shouldSetFirst ? 0 : option.items.len()
  option.items.insert(idx, {
    text = locName
    textStyle = ::COLORED_DROPRIGHT_TEXT_STYLE
    image = needIcon ? decorator.getSmallIcon() : null
  })
  option.values.insert(idx, value)
  option.decorators.insert(idx, decorator)
  option.access.insert(idx, {
    isOwn = true
    unlockId  = ""
    canBuy    = false
    price     = ::zero_money
    isVisible = true
    isDownloadable = false
  })
  return option.access[idx]
}

g_decorator.getSkinsOption <- function getSkinsOption(unitName, showLocked=false, needAutoSkin = true, showDownloadable = false)
{
  let descr = {
    items = []
    values = []
    access = []
    decorators = []
    value = 0
  }

  let unit = ::getAircraftByName(unitName)
  if (!unit)
    return descr

  let needIcon = unit.esUnitType == ::ES_UNIT_TYPE_TANK

  local skins = unit.getSkins()
  if (showDownloadable)
    skins = addDownloadableLiveSkins(skins, unit)

  for (local skinNo = 0; skinNo < skins.len(); skinNo++)
  {
    let skin = skins[skinNo]
    let isDefault = skin.name.len() == 0
    let skinName = isDefault ? DEFAULT_SKIN_NAME : skin.name // skin ID (default skin stored in profile with name 'default')

    let skinBlockName = unitName + "/"+ skinName

    let isPreviewedLiveSkin = ::has_feature("EnableLiveSkins") && ::isInArray(skinBlockName, previewedLiveSkinIds)
    local decorator = ::g_decorator.getDecorator(skinBlockName, ::g_decorator_type.SKINS)
    if (!decorator)
    {
      if (isPreviewedLiveSkin)
        decorator = ::Decorator(skinBlockName, ::g_decorator_type.SKINS);
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
      || ::is_unlock_visible(decorator.unlockBlk)
    if (!isVisible && !::is_dev_version)
      continue

    let access = addSkinItemToOption(descr, decorator.getName(), skinName, decorator, false, needIcon)
    access.isOwn = isOwn
    access.unlockId  = !isOwn && decorator.unlockBlk ? decorator.unlockId : ""
    access.canBuy    = decorator.canBuyUnlock(unit)
    access.price     = cost
    access.isVisible = isVisible
    access.isDownloadable = skin?.isDownloadable ?? false
  }

  let hasAutoSkin = needAutoSkin && isAutoSkinAvailable(unitName)
  if (hasAutoSkin)
  {
    let autoSkin = getAutoSkin(unitName)
    let decorator = ::g_decorator.getDecorator(unitName + "/"+ autoSkin, ::g_decorator_type.SKINS)
    let locName = ::loc("skins/auto", { skin = decorator ? decorator.getName() : "" })
    addSkinItemToOption(descr, locName, null, decorator, true, needIcon)
  }

  let curSkin = getLastSkin(unit.name)
  descr.value = ::find_in_array(descr.values, curSkin, -1)
  if (descr.value != -1 || !descr.values.len())
    return descr

  descr.value = 0
  if (curSkin && curSkin != "")//cur skin is not valid, need set valid skin
    setLastSkin(unit.name, descr.values[0], hasAutoSkin)

  return descr
}

g_decorator.onEventSignOut <- function onEventSignOut(p)
{
  ::g_decorator.clearCache()
}

g_decorator.onEventLoginComplete <- function onEventLoginComplete(p)
{
  ::g_decorator.clearCache()
}

g_decorator.onEventDecalReceived <- function onEventDecalReceived(p)
{
  if (p?.id)
    updateDecalVisible(p, ::g_decorator_type.DECALS)
}

g_decorator.onEventAttachableReceived <- function onEventAttachableReceived(p)
{
  if (p?.id)
    updateDecalVisible(p, ::g_decorator_type.ATTACHABLES)
}

let function addDecoratorToCachedData(decorator, data) {
  let category = decorator.category
  if (!(category in data.decorators)) {
    data.decorators[category] <- []
    data.categories.append(category)
  }
  ::u.appendOnce(decorator, data.decorators[category], true, @(a, b) a?.id == b.id)
}

g_decorator.updateDecalVisible <- function updateDecalVisible(params, decType)
{
  let decorId = params.id
  let data = getCachedDataByType(decType)
  let decorator = data.decoratorsList?[decorId]

  if (!decorator || (!decorator.isVisible() && !decorator.isForceVisible()))
    return

  addDecoratorToCachedData(decorator, data)

  foreach (unitType in unitTypes.types) {
    if (decorator.isAllowedByUnitTypes(unitType.tag)) {
      let dataByUnitType = getCachedDataByType(decType, unitType.tag)
      addDecoratorToCachedData(decorator, dataByUnitType)
    }
  }
}

g_decorator.onEventUnitBought <- function onEventUnitBought(p)
{
  applyPreviewSkin(p)
}

g_decorator.onEventUnitRented <- function onEventUnitRented(p)
{
  applyPreviewSkin(p)
}

g_decorator.applyPreviewSkin <- function applyPreviewSkin(params)
{
  let unit = ::getAircraftByName(params?.unitName)
  if (!unit)
    return

  let previewSkinId = unit.getPreviewSkinId()
  if (previewSkinId == "")
    return

  setLastSkin(unit.name, previewSkinId, false)

  ::save_online_single_job(3210)
  ::save_profile(false)
}

g_decorator.isPreviewingLiveSkin <- function isPreviewingLiveSkin()
{
  return ::has_feature("EnableLiveSkins") && ::g_decorator.previewedLiveSkinIds.len() > 0
}

g_decorator.buildLiveDecoratorFromResource <- function buildLiveDecoratorFromResource(resource, resourceType, itemDef, params)
{
  if (!resource || !resourceType)
    return
  let decoratorId = (params?.unitId != null && resourceType == "skin")
    ? ::g_unlocks.getSkinId(params.unitId, resource)
    : resource
  if (decoratorId in ::g_decorator.liveDecoratorsCache)
    return

  let decorator = ::Decorator(decoratorId, ::g_decorator_type.getTypeByResourceType(resourceType))
  decorator.updateFromItemdef(itemDef)
  ::add_rta_localization($"{decoratorId}", itemDef.name)
  ::add_rta_localization($"{decoratorId}/desc", itemDef.description)

  ::g_decorator.liveDecoratorsCache[decoratorId] <- decorator

  // Also replacing a fake skin decorator created by item constructor
  if (resource != decoratorId)
    ::g_decorator.liveDecoratorsCache[resource] <- decorator
}

g_decorator.onEventItemsShopUpdate <- function onEventItemsShopUpdate(p)
{
  foreach (itemDefId, decorator in waitingItemdefs)
  {
    let couponItem = ::ItemsManager.findItemById(itemDefId)
    if (couponItem)
    {
      decorator.updateFromItemdef(couponItem.itemDef)
      waitingItemdefs[itemDefId] = null
    }
  }
  waitingItemdefs = waitingItemdefs.filter(@(v) v != null)
}

::subscribe_handler(::g_decorator, ::g_listener_priority.CONFIG_VALIDATION)
