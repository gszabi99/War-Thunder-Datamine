from "%scripts/dagui_natives.nut" import live_preview_resource, live_preview_resource_for_approve, live_preview_resource_by_guid
from "%scripts/dagui_library.nut" import *
from "%scripts/customization/customizationConsts.nut" import PREVIEW_MODE

let { eventbus_subscribe } = require("eventbus")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { hangar_is_model_loaded, hangar_get_loaded_unit_name } = require("hangar")
let guidParser = require("%scripts/guidParser.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { showedUnit, getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { APP_ID } = require("app")
let { isCollectionPrize } = require("%scripts/collections/collections.nut")
let { hasAvailableCollections } = require("%scripts/collections/collectionsHandler.nut")
let { getDecorator, getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let { getPlaneBySkinId, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { getUnitName, isLoadedModelHighQuality } = require("%scripts/unit/unitInfo.nut")
let { decoratorTypes, getTypeByResourceType } = require("%scripts/customization/types.nut")
let { isInHangar } = require("gameplayBinding")
let { addPopup } = require("%scripts/popups/popups.nut")
let { add_msg_box } = require("%sqDagui/framework/msgBox.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { getBestUnitForPreview } = require("%scripts/customization/contentPreviewState.nut")
let { hasSessionInLobby } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { checkPackageAndAskDownload } = require("%scripts/clientState/contentPacks.nut")
let { get_last_skin } = require("unitCustomization")

let downloadTimeoutSec = 15
local downloadProgressBox = null

local onSkinReadyToShowCallback = null

local waitingItemDefId = null

function gui_start_decals(params = null) {
  if (params?.unit)
    showedUnit(params.unit)
  else if (params?.unitId)
    showedUnit(getAircraftByName(params?.unitId))

  if (!showedUnit.value
      ||
        (hangar_get_loaded_unit_name() == showedUnit.value.name
        && !isLoadedModelHighQuality()
        && !checkPackageAndAskDownload("pkg_main"))
    )
    return

  params = params || {}
  params.backSceneParams <- { eventbusName = "gui_start_mainmenu" }
  loadHandler(gui_handlers.DecalMenuHandler, params)
}

eventbus_subscribe("gui_start_decals", gui_start_decals)

function getCantStartPreviewSceneReason(shouldAllowFromCustomizationScene = false) {
  if (!isLoggedIn.get())
    return "not_logged_in"
  if (!isInHangar())
    return "not_in_hangar"
  if (!hangar_is_model_loaded())
    return "hangar_not_ready"
  if (!isInMenu.get() || isAnyQueuesActive()
      || (g_squad_manager.isSquadMember() && g_squad_manager.isMeReady())
      || hasSessionInLobby())
    return "temporarily_forbidden"
  let customizationScene = handlersManager.findHandlerClassInScene(gui_handlers.DecalMenuHandler)
  if (customizationScene && (!shouldAllowFromCustomizationScene || !customizationScene.canRestartSceneNow()))
    return "temporarily_forbidden"
  return  ""
}

function canStartPreviewScene(shouldShowFordiddenPopup, shouldAllowFromCustomizationScene = false) {
  let reason = getCantStartPreviewSceneReason(shouldAllowFromCustomizationScene)
  if (shouldShowFordiddenPopup && reason == "temporarily_forbidden")
    addPopup("", loc("mainmenu/itemPreviewForbidden"))
  return reason == ""
}







function showUnitSkin(unitId, skinId = null, isForApprove = false) {
  if (!canStartPreviewScene(true, true))
    return

  let unit = getAircraftByName(unitId)
  if (!unit)
    return false

  if (unit.isUsableSlaveUnit() && (skinId == null || skinId == ""))
    skinId = get_last_skin(unit.masterUnit)

  let unitPreviewSkin = unit.getPreviewSkinId()
  skinId = skinId || unitPreviewSkin
  let isUnitPreview = skinId == unitPreviewSkin

  broadcastEvent("BeforeStartShowroom")
  showedUnit(unit)
  let startFunc = function() {
    gui_start_decals({
      previewMode = isUnitPreview ? PREVIEW_MODE.UNIT : PREVIEW_MODE.SKIN
      needForceShowUnitInfoPanel = isUnitPreview && isUnitSpecial(unit)
      previewParams = {
        unitName = unitId
        skinName = skinId
        isForApprove = isForApprove
      }
    })
  }
  handlersManager.animatedSwitchScene(startFunc())

  return true
}







function showUnitDecorator(unitId, resource, resourceType) {
  if (!canStartPreviewScene(true, true))
    return

  let decoratorType = getTypeByResourceType(resourceType)
  if (decoratorType == decoratorTypes.UNKNOWN)
    return false

  let decorator = getDecorator(resource, decoratorType)
  if (!decorator)
    return false

  let unit = getBestUnitForPreview(@(unitType) decorator.isAllowedByUnitTypes(unitType),
    @(un, checkUnitUsable = true) decoratorType.isAvailable(un, checkUnitUsable),
    unitId)
  if (!unit)
    return false

  let hangarUnit = getPlayerCurUnit()
  broadcastEvent("BeforeStartShowroom")
  showedUnit(unit)
  let params = {
    previewMode = PREVIEW_MODE.DECORATOR
    initialUnitId = hangarUnit?.name
    previewParams = {
      unitName = unit.name
      resource
      resourceType
    }
  }
  gui_start_decals(params)
  handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_decals", params })

  return true
}









function showResource(resource, resourceType, onSkinReadyToShowCb = null) {
  if (!canStartPreviewScene(true, true))
    return

  onSkinReadyToShowCallback = (resourceType == "skin")
    ? onSkinReadyToShowCb
    : null

  if (guidParser.isGuid(resource)) {
    downloadProgressBox = scene_msg_box("live_resource_requested", null, loc("msgbox/please_wait"),
      [["cancel"]], "cancel", { waitAnim = true, delayedButtons = downloadTimeoutSec })
    live_preview_resource_by_guid(resource, resourceType)
  }
  else {
    if (resourceType == "skin") {
      let unitId = getPlaneBySkinId(resource)
      let skinId  = getSkinNameBySkinId(resource)
      showUnitSkin(unitId, skinId)
    }
    else if (resourceType == "decal" || resourceType == "attachable") {
      showUnitDecorator(null, resource, resourceType)
    }
  }
}

function liveSkinPreview(params) {
  if (!hasFeature("EnableLiveSkins"))
    return "not_allowed"
  let reason = getCantStartPreviewSceneReason(true)
  if (reason != "")
    return reason

  let blkHashName = params.hash
  let name = params?.name ?? "testName"
  let shouldPreviewForApprove = params?.previewForApprove ?? false
  let res = shouldPreviewForApprove ? live_preview_resource_for_approve(blkHashName, "skin", name)
                                      : live_preview_resource(blkHashName, "skin", name)
  return res.result
}

function onSkinDownloaded(unitId, skinId, result) {
  if (downloadProgressBox)
    destroyMsgBox(downloadProgressBox)

  if (onSkinReadyToShowCallback) {
    onSkinReadyToShowCallback(unitId, skinId, result)
    onSkinReadyToShowCallback = null
    return
  }

  if (result)
    showUnitSkin(unitId, skinId)
}

function marketViewItem(params) {
  if (to_integer_safe(params?.appId, 0, false) != APP_ID)
    return
  let assets = (params?.assetClass ?? []).filter(@(asset) asset?.name == "__itemdefid")
  if (!assets.len())
    return
  let itemDefId = to_integer_safe(assets?[0]?.value)
  let item = findItemById(itemDefId)
  if (!item) {
    waitingItemDefId = itemDefId
    return
  }
  waitingItemDefId = null
  if (item.canPreview() && canStartPreviewScene(true, true))
    item.doPreview()
}

function requestUnitPreview(params) {
  let reason = getCantStartPreviewSceneReason(true)
  if (reason != "")
    return reason
  let unit = getAircraftByName(params?.unitId)
  if (unit == null)
    return "unit_not_found"
  if (!unit.canPreview())
    return "unit_not_viewable"
  unit.doPreview()
  return "success"
}

function onEventItemsShopUpdate(_params) {
  if (waitingItemDefId == null)
    return
  let item = findItemById(waitingItemDefId)
  if (!item)
    return
  waitingItemDefId = null
  if (item.canPreview() && canStartPreviewScene(true, true))
    item.doPreview()
}

function getDecoratorDataToUse(resource, resourceType) {
  let res = {
    decorator = null
    decoratorUnit = null
    decoratorSlot = null
  }
  let decorator = getDecoratorByResource(resource, resourceType)
  if (decorator == null)
    return res

  let decoratorType = decorator.decoratorType
  let decoratorUnit = decoratorType == decoratorTypes.SKINS
    ? getAircraftByName(getPlaneBySkinId(decorator.id))
    : getPlayerCurUnit()

  if (decoratorUnit == null || !decoratorType.isAvailable(decoratorUnit) || !decorator.canUse(decoratorUnit))
    return res

  let freeSlotIdx = decoratorType.getFreeSlotIdx(decoratorUnit)
  let decoratorSlot = freeSlotIdx != -1 ? freeSlotIdx
    : (decoratorType.getAvailableSlots(decoratorUnit) - 1)

  return {
    decorator
    decoratorUnit
    decoratorSlot
  }
}

function showDecoratorAccessRestriction(decorator, unit, needShowMessageBox = false) {
  if (!decorator || decorator.canUse(unit))
    return false

  let text = []
  if (decorator.isLockedByCountry(unit))
    text.append(loc("mainmenu/decalNotAvailable"))

  if (decorator.isLockedByUnit(unit)) {
    let unitsList = []
    foreach (unitName in decorator.units)
      unitsList.append(colorize("userlogColoredText", getUnitName(unitName)))
    text.append(loc("mainmenu/decoratorAvaiblableOnlyForUnit", {
      decoratorName = colorize("activeTextColor", decorator.getName()),
      unitsList = ",".join(unitsList, true) }))
  }

  if (!decorator.isAllowedByUnitTypes(unit.unitType.tag))
    text.append(loc("mainmenu/decoratorAvaiblableOnlyForUnitTypes", {
      decoratorName = colorize("activeTextColor", decorator.getName()),
      unitTypesList = decorator.getLocAllowedUnitTypes()
    }))

  if (decorator.lockedByDLC != null)
    text.append(format(loc("mainmenu/decalNoCampaign"), loc($"charServer/entitlement/{decorator.lockedByDLC}")))

  if (text.len() != 0) {
    let infoText = ", ".join(text, true)
    if (needShowMessageBox)
      showInfoMsgBox(infoText)
    else
      addPopup("", infoText)
    return true
  }

  if (decorator.isUnlocked() || decorator.canBuyUnlock(unit) || decorator.canBuyCouponOnMarketplace(unit))
    return false

  if (hasAvailableCollections() && isCollectionPrize(decorator)) {
    let locText = loc("mainmenu/decoratorNoCompletedCollection" {
      decoratorName = colorize("activeTextColor", decorator.getName())
    })

    if (needShowMessageBox)
      add_msg_box("safe_unfinished", locText,
        [
          ["#collection/go_to_collection", function() {
            broadcastEvent("ShowCollection", { selectedDecoratorId = decorator.id })
          }],
          ["cancel", function() {}]
        ], "cancel")
    else
      addPopup(
        null,
        locText,
        null,
        [{
          id = "gotoCollection"
          text = loc("collection/go_to_collection")
          func = @() broadcastEvent("ShowCollection", { selectedDecoratorId = decorator.id })
        }])
    return true
  }

  if (needShowMessageBox)
    showInfoMsgBox(loc("mainmenu/decalNoAchievement"))
  else
    addPopup("", loc("mainmenu/decalNoAchievement"))

  return true
}

function useDecorator(decorator, decoratorUnit, decoratorSlot) {
  if (!decorator)
    return
  if (!canStartPreviewScene(true))
    return
  gui_start_decals({
    unit = decoratorUnit
    preSelectDecorator = decorator
    preSelectDecoratorSlot = decoratorSlot
  })
}

let doDelayed = @(action) get_gui_scene().performDelayed({}, action)

globalCallbacks.addTypes({
  ITEM_PREVIEW = {
    onCb = function(_obj, params) {
      let item = findItemById(params?.itemId)
      if (item && item.canPreview() && canStartPreviewScene(true, true))
        doDelayed(@() item.doPreview())
    }
  }
  ITEM_LINK = {
    onCb = function(_obj, params) {
      let item = findItemById(params?.itemId)
      if (item && item.hasLink())
        doDelayed(@() item.openLink())
    }
  }
  UNIT_PREVIEW = {
    onCb = function(_obj, params) {
      let unit = getAircraftByName(params?.unitId)
      if (unit && unit.canPreview() && canStartPreviewScene(true, true))
        doDelayed(@() unit.doPreview())
    }
  }
  DECORATOR_PREVIEW = {
    onCb = function(_obj, params) {
      let decorator = getDecoratorByResource(params?.resource, params?.resourceType)
      if (decorator && decorator.canPreview() && canStartPreviewScene(true, true))
        doDelayed(@() decorator.doPreview())
    }
  }
})





getroottable()["live_start_unit_preview"] <- @(unitId, skinId, isForApprove) showUnitSkin(unitId, skinId, isForApprove)

web_rpc.register_handler("ugc_skin_preview", @(params) liveSkinPreview(params))
web_rpc.register_handler("market_view_item", @(params) marketViewItem(params))
web_rpc.register_handler("request_view_unit", @(params) requestUnitPreview(params))

eventbus_subscribe("onLiveSkinDataLoaded", @(res) onSkinDownloaded(res.unitId, res.skinGuid, res.result))
eventbus_subscribe("liveStartUnitPreview", @(res) showUnitSkin(res.unitId, res.skinId, res.isForApprove))

subscriptions.addListenersWithoutEnv({
  ItemsShopUpdate = @(p) onEventItemsShopUpdate(p)
})

return {
  showUnitSkin = showUnitSkin
  showResource = showResource
  canStartPreviewScene = canStartPreviewScene
  getBestUnitForPreview
  getDecoratorDataToUse
  useDecorator
  showDecoratorAccessRestriction
  gui_start_decals
}
