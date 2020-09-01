local skinLocations = require("scripts/customization/skinLocations.nut")
local guidParser = require("scripts/guidParser.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { getDownloadableSkins } = require("scripts/customization/downloadableDecorators.nut")

const DEFAULT_SKIN_NAME = "default"

//code callback
::on_dl_content_skins_invalidate <- function on_dl_content_skins_invalidate()
{
  ::g_decorator.clearCache()
}

//code callback
::update_unit_skins_list <- function update_unit_skins_list(unitName)
{
  local unit = ::getAircraftByName(unitName)
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
    local downloadableSkins = getDownloadableSkins(unit)
    if (downloadableSkins.len() == 0)
      return skins

    skins = [].extend(skins)

    foreach (itemdefId in downloadableSkins)
    {
      local resource = ::ItemsManager.findItemById(itemdefId)?.getMetaResource()
      if (resource == null)
        continue

      if (guidParser.isGuid(resource)) // Live skin
      {
        local foundIdx = skins.findindex(@(s) s?.name == resource)
        local skin = (foundIdx != null)
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
        local skinName = ::g_unlocks.getSkinNameBySkinId(resource)
        local skin = skins.findvalue(@(s) s?.name == skinName)
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

g_decorator.getCachedDataByType <- function getCachedDataByType(decType)
{
  local id = "proceedData_" + decType.name
  if (id in ::g_decorator.cache)
    return ::g_decorator.cache[id]

  local data = ::g_decorator.splitDecoratorData(decType)
  ::g_decorator.cache[id] <- data
  return data
}

g_decorator.getCachedDecoratorsDataByType <- function getCachedDecoratorsDataByType(decType)
{
  local data = ::g_decorator.getCachedDataByType(decType)
  return data.decorators
}

g_decorator.getCachedOrderByType <- function getCachedOrderByType(decType)
{
  local data = ::g_decorator.getCachedDataByType(decType)
  return data.categories
}

g_decorator.getCachedDecoratorsListByType <- function getCachedDecoratorsListByType(decType)
{
  local data = ::g_decorator.getCachedDataByType(decType)
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
    local res = getDecorator(searchId, t)
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

  local path = "decoratorByUnlockId"
  if (!(path in ::g_decorator.cache))
    ::g_decorator.cache[path] <- {}

  if (unlockId in ::g_decorator.cache[path])
    return getDecorator(::g_decorator.cache[path][unlockId], decType)

  local foundDecorator = ::u.search(::g_decorator.getCachedDecoratorsListByType(decType),
      (@(unlockId) function(d) {
        return d.unlockId == unlockId
      })(unlockId))

  if (foundDecorator == null)
    return null

  ::g_decorator.cache[path][unlockId] <- foundDecorator.id
  return foundDecorator
}

g_decorator.splitDecoratorData <- function splitDecoratorData(decType)
{
  local result = {
    decorators = {}
    categories = []
    decoratorsList = {}
    fullBlk = null
  }

  local blk = decType.getBlk()
  if (::u.isEmpty(blk))
    return result

  result.fullBlk = blk

  local prevCategory = ""
  for (local c = 0; c < blk.blockCount(); c++)
  {
    local dblk = blk.getBlock(c)
    local category = dblk?.category ?? prevCategory

    if (!(category in result.decorators))
    {
      result.categories.append(category)
      result.decorators[category] <- []
    }

    local decorator = ::Decorator(dblk, decType)
    decorator.category = category
    decorator.catIndex = result.decorators[category].len()

    if (decorator.getCouponItemdefId() != null && !::ItemsManager.findItemById(decorator.getCouponItemdefId()))
      waitingItemdefs[decorator.getCouponItemdefId()] <- decorator

    result.decoratorsList[decorator.id] <- decorator
    if (decorator.isVisible() || decorator.isForceVisible())
      result.decorators[category].append(decorator)
  }

  foreach (category, decoratorsList in result.decorators)
    if (!decoratorsList.len())
    {
      result.categories.remove(::find_in_array(result.categories, category))
      delete result.decorators[category]
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
  local unit = getAircraftByName(unitName)
  if (!unit.isUsable() && unit.getPreviewSkinId() != "")
    return unit.getPreviewSkinId()
  if (!isAutoSkinAvailable(unitName))
    return ::hangar_get_last_skin(unitName)
  return ::load_local_account_settings(getSkinSaveId(unitName))
}

::g_decorator.isAutoSkinOn <- @(unitName) !getLastSkin(unitName)

g_decorator.getRealSkin <- function getRealSkin(unitName)
{
  local res = getLastSkin(unitName)
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
  local list = getBestSkinsList(unitName, isLockedAllowed)
  if (!list.len())
    return DEFAULT_SKIN_NAME
  return list[list.len() - 1 - (::SessionLobby.roomId % list.len())] //use last skin when no in session
}

g_decorator.getBestSkinsList <- function getBestSkinsList(unitName, isLockedAllowed)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return [DEFAULT_SKIN_NAME]

  local misBlk = ::is_in_flight() ? ::get_current_mission_info_cached()
    : ::get_mission_meta_info(unit.testFlight)
  local level = misBlk?.level
  if (!level)
    return [DEFAULT_SKIN_NAME]

  local skinsList = [DEFAULT_SKIN_NAME]
  foreach(skin in unit.getSkins())
  {
    if (skin.name == "")
      continue
    if (isLockedAllowed)
    {
      skinsList.append(skin.name)
      continue
    }
    local decorator = ::g_decorator.getDecorator(unitName + "/"+ skin.name, ::g_decorator_type.SKINS)
    if (decorator && decorator.isUnlocked())
      skinsList.append(skin.name)
  }
  return skinLocations.getBestSkinsList(skinsList, unitName, level)
}

g_decorator.addSkinItemToOption <- function addSkinItemToOption(option, locName, value, decorator, shouldSetFirst = false, needIcon = false)
{
  local idx = shouldSetFirst ? 0 : option.items.len()
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
  local descr = {
    items = []
    values = []
    access = []
    decorators = []
    value = 0
  }

  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return descr

  local needIcon = unit.esUnitType == ::ES_UNIT_TYPE_TANK

  local skins = unit.getSkins()
  if (showDownloadable)
    skins = addDownloadableLiveSkins(skins, unit)

  for (local skinNo = 0; skinNo < skins.len(); skinNo++)
  {
    local skin = skins[skinNo]
    local isDefault = skin.name.len() == 0
    local skinName = isDefault ? DEFAULT_SKIN_NAME : skin.name // skin ID (default skin stored in profile with name 'default')

    local skinBlockName = unitName + "/"+ skinName

    local isPreviewedLiveSkin = ::has_feature("EnableLiveSkins") && ::isInArray(skinBlockName, previewedLiveSkinIds)
    local decorator = ::g_decorator.getDecorator(skinBlockName, ::g_decorator_type.SKINS)
    if (!decorator)
    {
      if (isPreviewedLiveSkin)
        decorator = ::Decorator(skinBlockName, ::g_decorator_type.SKINS);
      else
        continue
    }

    local isUnlocked = decorator.isUnlocked()
    local isOwn = isDefault || isUnlocked

    if (!isOwn && !showLocked)
      continue

    local forceVisible = skin?.forceVisible || isPreviewedLiveSkin

    if (!decorator.isVisible() && !forceVisible)
      continue

    local cost = decorator.getCost()
    local hasPrice = !cost.isZero()
    local isVisible = isDefault || isOwn || hasPrice || ::is_unlock_visible(decorator.unlockBlk)|| forceVisible
    if (!isVisible && !::is_dev_version)
      continue

    local access = addSkinItemToOption(descr, decorator.getName(), skinName, decorator, false, needIcon)
    access.isOwn = isOwn
    access.unlockId  = !isOwn && decorator.unlockBlk ? decorator.unlockId : ""
    access.canBuy    = decorator.canBuyUnlock(unit)
    access.price     = cost
    access.isVisible = isVisible
    access.isDownloadable = skin?.isDownloadable ?? false
  }

  local hasAutoSkin = needAutoSkin && isAutoSkinAvailable(unitName)
  if (hasAutoSkin)
  {
    local autoSkin = getAutoSkin(unitName)
    local decorator = ::g_decorator.getDecorator(unitName + "/"+ autoSkin, ::g_decorator_type.SKINS)
    local locName = ::loc("skins/auto", { skin = decorator ? decorator.getName() : "" })
    addSkinItemToOption(descr, locName, null, decorator, true, needIcon)
  }

  local curSkin = getLastSkin(unit.name)
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

g_decorator.updateDecalVisible <- function updateDecalVisible(params, decType)
{
  local decorId = params.id
  local data = getCachedDataByType(decType)
  local decorator = data.decoratorsList?[decorId]
  local category = decorator?.category

  if (!decorator || (!decorator.isVisible() && !decorator.isForceVisible()))
    return

  if (!(category in data.decorators))
  {
    data.decorators[category] <- []
    data.categories.append(category)
  }
  ::u.appendOnce(decorator, data.decorators[category])
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
  local unit = ::getAircraftByName(params?.unitName)
  if (!unit)
    return

  local previewSkinId = unit.getPreviewSkinId()
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
  local decoratorId = (params?.unitId != null && resourceType == "skin")
    ? ::g_unlocks.getSkinId(params.unitId, resource)
    : resource
  if (decoratorId in ::g_decorator.liveDecoratorsCache)
    return

  local decorator = ::Decorator(decoratorId, ::g_decorator_type.getTypeByResourceType(resourceType))
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
    local couponItem = ::ItemsManager.findItemById(itemDefId)
    if (couponItem)
    {
      decorator.updateFromItemdef(couponItem.itemDef)
      waitingItemdefs[itemDefId] = null
    }
  }
  waitingItemdefs = waitingItemdefs.filter(@(v) v != null)
}

::subscribe_handler(::g_decorator, ::g_listener_priority.CONFIG_VALIDATION)
