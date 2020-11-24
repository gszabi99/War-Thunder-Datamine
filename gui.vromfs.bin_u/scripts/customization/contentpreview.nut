local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local guidParser = require("scripts/guidParser.nut")
local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")

local downloadTimeoutSec = 15
local downloadProgressBox = null

local onSkinReadyToShowCallback = null

local waitingItemDefId = null

local function getCantStartPreviewSceneReason(shouldAllowFromCustomizationScene = false)
{
  if (!::g_login.isLoggedIn())
    return "not_logged_in"
  if (!::is_in_hangar())
    return "not_in_hangar"
  if (!hangar_is_loaded())
    return "hangar_not_ready"
  if (!::isInMenu() || ::checkIsInQueue()
      || (::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady())
      || ::SessionLobby.hasSessionInLobby())
    return "temporarily_forbidden"
  local customizationScene = ::handlersManager.findHandlerClassInScene(::gui_handlers.DecalMenuHandler)
  if (customizationScene && (!shouldAllowFromCustomizationScene || !customizationScene.canRestartSceneNow()))
    return "temporarily_forbidden"
  return  ""
}

local function canStartPreviewScene(shouldShowFordiddenPopup, shouldAllowFromCustomizationScene = false)
{
  local reason = getCantStartPreviewSceneReason(shouldAllowFromCustomizationScene)
  if (shouldShowFordiddenPopup && reason == "temporarily_forbidden")
    ::g_popups.add("", ::loc("mainmenu/itemPreviewForbidden"))
  return reason == ""
}

/**
 * Starts Customization scene with given unit and optional skin.
 * @param {string} unitId - Unit to show.
 * @param {string|null} [skinId] - Skin to apply. Use null for default skin.
 * @param {boolean} [isForApprove] - Enables UI for skin approvement.
 */
local function showUnitSkin(unitId, skinId = null, isForApprove = false)
{
  if (!canStartPreviewScene(true, true))
    return

  local unit = ::getAircraftByName(unitId)
  if (!unit)
    return false

  local unitPreviewSkin = unit.getPreviewSkinId()
  skinId = skinId || unitPreviewSkin
  local isUnitPreview = skinId == unitPreviewSkin

  ::broadcastEvent("BeforeStartShowroom")
  ::show_aircraft = unit
  local startFunc = function() {
    ::gui_start_decals({
      previewMode = isUnitPreview ? PREVIEW_MODE.UNIT : PREVIEW_MODE.SKIN
      needForceShowUnitInfoPanel = isUnitPreview && ::isUnitSpecial(unit)
      previewParams = {
        unitName = unitId
        skinName = skinId
        isForApprove = isForApprove
      }
    })
  }
  ::handlersManager.animatedSwitchScene(startFunc())

  return true
}

local function getBestUnitForDecoratorPreview(decoratorType, forcedUnitId = null)
{
  local unit = null
  if (forcedUnitId)
  {
    unit = ::getAircraftByName(forcedUnitId)
    return decoratorType.isAvailable(unit, false) ? unit : null
  }

  unit = ::get_player_cur_unit()
  if (decoratorType.isAvailable(unit, false))
    return unit

  local countryId = ::get_profile_country_sq()
  local crews = ::get_crews_list_by_country(countryId)

  foreach (crew in crews)
    if ((crew?.aircraft ?? "") != "")
    {
      unit = ::getAircraftByName(crew.aircraft)
      if (decoratorType.isAvailable(unit, false))
        return unit
    }

  foreach (crew in crews)
    for (local i = crew.trained.len() - 1; i >= 0; i--)
    {
      unit = ::getAircraftByName(crew.trained[i])
      if (decoratorType.isAvailable(unit, false))
        return unit
    }

  unit = ::getAircraftByName(::getReserveAircraftName({
    country = countryId
    unitType = ::ES_UNIT_TYPE_TANK
    ignoreSlotbarCheck = true
  }))
  if (decoratorType.isAvailable(unit, false))
    return unit

  unit = ::getAircraftByName(::getReserveAircraftName({
    country = "country_usa"
    unitType = ::ES_UNIT_TYPE_TANK
    ignoreSlotbarCheck = true
  }))
  if (decoratorType.isAvailable(unit, false))
    return unit

  return null
}

/**
 * Starts Customization scene with some conpatible unit and given decorator.
 * @param {string|null} unitId - Unit to show. Use null to auto select some compatible unit.
 * @param {string} resource - Resource.
 * @param {string} resourceType - Resource type.
 */
local function showUnitDecorator(unitId, resource, resourceType)
{
  if (!canStartPreviewScene(true, true))
    return

  local decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
  if (decoratorType == ::g_decorator_type.UNKNOWN)
    return false

  local decorator = ::g_decorator.getDecorator(resource, decoratorType)
  if (!decorator)
    return false

  local unit = getBestUnitForDecoratorPreview(decoratorType, unitId)
  if (!unit)
    return false

  local hangarUnit = ::get_player_cur_unit()
  ::broadcastEvent("BeforeStartShowroom")
  ::show_aircraft = unit
  local startFunc = function() {
    ::gui_start_decals({
      previewMode = PREVIEW_MODE.DECORATOR
      initialUnitId = hangarUnit?.name
      previewParams = {
        unitName = unit.name
        decorator = decorator
      }
    })
  }
  startFunc()
  ::handlersManager.setLastBaseHandlerStartFunc(startFunc)

  return true
}

/**
 * If resource id GUID, then downloads it first.
 * Then starts Customization scene with given resource preview.
 * @param {string} resource - Resource. Can be GUID.
 * @param {string} resourceType - Resource type.
 * @param {function} onSkinReadyToShowCb - Optional custom function to be called when
 *                   skin prepared to show. Function must take params: (unitId, skinId, result).
 */
local function showResource(resource, resourceType, onSkinReadyToShowCb = null)
{
  if (!canStartPreviewScene(true, true))
    return

  onSkinReadyToShowCallback = (resourceType == "skin")
    ? onSkinReadyToShowCb
    : null

  if (guidParser.isGuid(resource))
  {
    downloadProgressBox = ::scene_msg_box("live_resource_requested", null, ::loc("msgbox/please_wait"),
      [["cancel"]], "cancel", { waitAnim = true, delayedButtons = downloadTimeoutSec })
    ::live_preview_resource_by_guid(resource, resourceType)
  }
  else
  {
    if (resourceType == "skin")
    {
      local unitId = ::g_unlocks.getPlaneBySkinId(resource)
      local skinId  = ::g_unlocks.getSkinNameBySkinId(resource)
      showUnitSkin(unitId, skinId)
    }
    else if (resourceType == "decal" || resourceType == "attachable")
    {
      showUnitDecorator(null, resource, resourceType)
    }
  }
}

local function liveSkinPreview(params)
{
  if (!::has_feature("EnableLiveSkins"))
    return "not_allowed"
  local reason = getCantStartPreviewSceneReason(true)
  if (reason != "")
    return reason

  local blkHashName = params.hash
  local name = params?.name ?? "testName"
  local shouldPreviewForApprove = params?.previewForApprove ?? false
  local res = shouldPreviewForApprove ? ::live_preview_resource_for_approve(blkHashName, "skin", name)
                                      : ::live_preview_resource(blkHashName, "skin", name)
  return res.result
}

local function onSkinDownloaded(unitId, skinId, result)
{
  if (downloadProgressBox)
    ::destroyMsgBox(downloadProgressBox)

  if (onSkinReadyToShowCallback)
  {
    onSkinReadyToShowCallback(unitId, skinId, result)
    onSkinReadyToShowCallback = null
    return
  }

  if (result)
    showUnitSkin(unitId, skinId)
}

local function marketViewItem(params)
{
  if (::to_integer_safe(params?.appId, 0, false) != ::WT_APPID)
    return
  local assets = ::u.filter(params?.assetClass ?? [], @(asset) asset?.name == "__itemdefid")
  if (!assets.len())
    return
  local itemDefId = ::to_integer_safe(assets?[0]?.value)
  local item = ::ItemsManager.findItemById(itemDefId)
  if (!item)
  {
    waitingItemDefId = itemDefId
    return
  }
  waitingItemDefId = null
  if (item.canPreview() && canStartPreviewScene(true, true))
    item.doPreview()
}

local function requestUnitPreview(params)
{
  local reason = getCantStartPreviewSceneReason(true)
  if (reason != "")
    return reason
  local unit = ::getAircraftByName(params?.unitId)
  if (unit == null)
    return "unit_not_found"
  if (!unit.canPreview())
    return "unit_not_viewable"
  unit.doPreview()
  return "success"
}

local function onEventItemsShopUpdate(params)
{
  if (waitingItemDefId == null)
    return
  local item = ::ItemsManager.findItemById(waitingItemDefId)
  if (!item)
    return
  waitingItemDefId = null
  if (item.canPreview() && canStartPreviewScene(true, true))
    item.doPreview()
}

local doDelayed = @(action) get_gui_scene().performDelayed({}, action)

globalCallbacks.addTypes({
  ITEM_PREVIEW = {
    onCb = function(obj, params) {
      local item = ::ItemsManager.findItemById(params?.itemId)
      if (item && item.canPreview() && canStartPreviewScene(true, true))
        doDelayed(@() item.doPreview())
    }
  }
  ITEM_LINK = {
    onCb = function(obj, params) {
      local item = ::ItemsManager.findItemById(params?.itemId)
      if (item && item.hasLink())
        doDelayed(@() item.openLink())
    }
  }
  UNIT_PREVIEW = {
    onCb = function(obj, params) {
      local unit = ::getAircraftByName(params?.unitId)
      if (unit && unit.canPreview() && canStartPreviewScene(true, true))
        doDelayed(@() unit.doPreview())
    }
  }
  DECORATOR_PREVIEW = {
    onCb = function(obj, params) {
      local decorator = ::g_decorator.getDecoratorByResource(params?.resource, params?.resourceType)
      if (decorator && decorator.canPreview() && canStartPreviewScene(true, true))
        doDelayed(@() decorator.doPreview())
    }
  }
})


/**
 * Creates global funcs, which are called from client.
 */
local rootTable = ::getroottable()
rootTable["on_live_skin_data_loaded"] <- @(unitId, skinGuid, result) onSkinDownloaded(unitId, skinGuid, result)
rootTable["live_start_unit_preview"]  <- @(unitId, skinId, isForApprove) showUnitSkin(unitId, skinId, isForApprove)
web_rpc.register_handler("ugc_skin_preview", @(params) liveSkinPreview(params))
web_rpc.register_handler("market_view_item", @(params) marketViewItem(params))
web_rpc.register_handler("request_view_unit", @(params) requestUnitPreview(params))

subscriptions.addListenersWithoutEnv({
  ItemsShopUpdate = @(p) onEventItemsShopUpdate(p)
})

return {
  showUnitSkin = showUnitSkin
  showResource = showResource
  canStartPreviewScene = canStartPreviewScene
}
