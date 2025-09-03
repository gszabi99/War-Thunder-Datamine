from "%scripts/dagui_natives.nut" import clan_get_exp, shop_get_country_excess_exp, wp_get_repair_cost, is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/clans/clanState.nut" import is_in_clan

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { getShopItem, canUseIngameShop, getShopItemsTable
} = require("%scripts/onlineShop/entitlementsShopData.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { repairWithMsgBox, flushSquadronExp, buyUnit, research } = require("%scripts/unit/unitActions.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let selectUnitHandler = require("%scripts/slotbar/selectUnitHandler.nut")
let selectGroupHandler = require("%scripts/slotbar/selectGroupHandler.nut")
let crewModalByVehiclesGroups = require("%scripts/crew/crewModalByVehiclesGroups.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let { checkUnitWeapons, checkUnitSecondaryWeapons,
  needSecondaryWeaponsWnd } = require("%scripts/weaponry/weaponryInfo.nut")
let { canBuyNotResearched, canResearchUnit, isUnitInResearch,
  isUnitDescriptionValid, isUnitUsable, isUnitFeatureLocked, isUnitResearched
} = require("%scripts/unit/unitStatus.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitWeaponryInfo.nut")
let { checkForResearch } = require("%scripts/unit/unitChecks.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getUnlockIdByUnitName, hasMarkerByUnitName } = require("%scripts/unlocks/unlockMarkers.nut")
let { KWARG_NON_STRICT } = require("%sqstd/functools.nut")
let openCrossPromoWnd = require("%scripts/openCrossPromoWnd.nut")
let { getUnitName, getUnitCountry, getUnitReqExp,
  getUnitExp, getUnitCost } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { canBuyUnit, isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let { needShowUnseenNightBattlesForUnit } = require("%scripts/events/nightBattlesStates.nut")
let { needShowUnseenModTutorialForUnit } = require("%scripts/missions/modificationTutorial.nut")
let { showUnitGoods } = require("%scripts/onlineShop/onlineShopModel.nut")
let takeUnitInSlotbar = require("%scripts/unit/takeUnitInSlotbar.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { gui_start_decals } = require("%scripts/customization/contentPreview.nut")
let { guiStartTestflight } = require("%scripts/missionBuilder/testFlightState.nut")
let { hasInWishlist, isWishlistFull } = require("%scripts/wishlist/wishlistManager.nut")
let { addToWishlist } = require("%scripts/wishlist/addWishWnd.nut")
let { getCrewMaxDiscountByInfo, getCrewDiscountInfo } = require("%scripts/crew/crewDiscount.nut")
let { openWishlist } = require("%scripts/wishlist/wishlistHandler.nut")
let { isCrewNeedUnseenIcon } = require("%scripts/crew/crew.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { getUnitCoupon, hasUnitCoupon } = require("%scripts/items/unitCoupons.nut")
let { getMaxWeaponryDiscountByUnitName } = require("%scripts/discounts/discountUtils.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { open_weapons_for_unit } = require("%scripts/weaponry/weaponryActions.nut")
let { canChangeCrewUnits } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { gui_modal_crew } = require("%scripts/crew/crewModalHandler.nut")
let { delayedTooltipOnHover } = require("%scripts/utils/delayedTooltip.nut")
let { gui_modal_convertExp } = require("%scripts/convertExpHandler.nut")
let { canBuyUnitOnMarketplace } = require("%scripts/unit/canBuyUnitOnMarketplace.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")
let { hasUnitEvent, getUnitEventId } = require("%scripts/unit/unitEvents.nut")
let { guiStartProfile } = require("%scripts/user/profileHandler.nut")

let getActions = kwarg(function getActions(unitObj, unit, actionsNames, crew = null, curEdiff = -1,
  isSlotbarEnabled = true, setResearchManually = null, needChosenResearchOfSquadron = false,
  isSquadronResearchMode = false, hasSlotbarByUnitsGroups = false, shopResearchMode = false,
  shouldCheckCrewsReady = false, onSpendExcessExp = null, onCloseShop = null, slotbar = null,
  cellClass = "slotbarClone"

) {
  let actions = []
  if (!unit || ("airsGroup" in unit) || actionsNames.len() == 0 || is_in_loading_screen())
    return actions

  let inMenu = isInMenu.get()
  let isUsable  = unit.isUsable()
  let isSlaveUnit = unit.isSlave()
  crew = crew ?? (hasSlotbarByUnitsGroups ? slotbarPresets.getCrewByUnit(unit) : getCrewByAir(unit))

  foreach (action in actionsNames) {
    local actionText = ""
    local showAction = false
    local actionFunc = null
    local haveWarning  = false
    local haveDiscount = false
    local disabled    = false
    local icon       = ""
    local isLink = false
    local isWarning = false
    local iconRotation = 0
    local isObjective = false
    local isShowDragAndDropIcon = false

    if (action == "showroom") {
      actionText = loc(isUsable ? "mainmenu/btnShowroom" : "mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#slot_showroom.svg"
      showAction = inMenu
      actionFunc = function () {
        checkQueueAndStart(function () {
          broadcastEvent("BeforeStartShowroom")
          showedUnit(unit)
          handlersManager.animatedSwitchScene(gui_start_decals)
        }, null, "isCanModifyCrew")
      }
    }
    else if (action == "preview") {
      actionText = loc("mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#btn_preview.svg"
      showAction = inMenu
      actionFunc = @() unit.doPreview()
    }
    else if (action == "aircraft") {
      if (crew == null || slotbar == null)
        continue

      actionText = loc("multiplayer/changeAircraft")
      isShowDragAndDropIcon = !showConsoleButtons.get()
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      showAction = inMenu && !isSlaveUnit && canChangeCrewUnits()
      actionFunc = function () {
        checkQueueAndStart(
          function() {
            checkSquadUnreadyAndDo(
              @() selectUnitHandler.open(crew, slotbar),
              @() null, shouldCheckCrewsReady)
          }, null, "isCanModifyCrew")
      }
    }
    else if (action == "crew") {
      if (crew == null)
        continue

      let discountInfo = getCrewDiscountInfo(crew.idCountry, crew.idInCountry)

      actionText = loc("mainmenu/btnCrew")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      haveWarning = isCrewNeedUnseenIcon(crew, unit)
      haveDiscount = getCrewMaxDiscountByInfo(discountInfo) > 0
      showAction = inMenu && !isSlaveUnit
      let params = {
        countryId = crew.idCountry,
        idInCountry = crew.idInCountry,
        curEdiff = curEdiff
        needHideSlotbar = !isSlotbarEnabled
      }

      actionFunc = function() {
        if (hasSlotbarByUnitsGroups)
          crewModalByVehiclesGroups.open(params)
        else
          gui_modal_crew(params)
      }
    }
    else if (action == "sec_weapons") {
      actionText = loc("options/secondary_weapons")
      icon       = "#ui/gameuiskin#slot_preset.svg"
      haveWarning = checkUnitSecondaryWeapons(unit) != UNIT_WEAPONS_READY
      haveDiscount = getMaxWeaponryDiscountByUnitName(unit.name, ["weapons"]) > 0
      showAction = inMenu && !isSlaveUnit &&
        needSecondaryWeaponsWnd(unit) && isUnitHaveSecondaryWeapons(unit)
      actionFunc = @() guiStartWeaponryPresets({
        unit = unit
        curEdiff = curEdiff
      })
    }
    else if (action == "goto_unlock") {
      if (hasSlotbarByUnitsGroups || !hasMarkerByUnitName(unit.name, curEdiff))
        continue

      actionText = loc("sm_objective")
      icon = "#ui/gameuiskin#sh_unlockachievement.svg"
      showAction = inMenu && !isSlaveUnit
      isObjective = true
      actionFunc = @() loadHandler(gui_handlers.Profile, {
        initialSheet = "UnlockAchievement"
        initialUnlockId = getUnlockIdByUnitName(unit.name, curEdiff)
      })
    }
    else if (action == "weapons") {
      actionText = loc("mainmenu/btnWeapons")
      icon       = "#ui/gameuiskin#btn_weapons.svg"
      haveWarning = checkUnitWeapons(unit, true) != UNIT_WEAPONS_READY
        || needShowUnseenNightBattlesForUnit(unit) || needShowUnseenModTutorialForUnit(unit)
      haveDiscount = getMaxWeaponryDiscountByUnitName(unit.name) > 0
      showAction = inMenu && !isSlaveUnit
      actionFunc = @() open_weapons_for_unit(unit, {
        curEdiff = curEdiff
        needHideSlotbar = !isSlotbarEnabled
      })
    }
    else if (action == "take") {
      actionText = loc("mainmenu/btnTakeAircraft")
      isShowDragAndDropIcon = !showConsoleButtons.get()
      icon       = "#ui/gameuiskin#slot_crew.svg"
      showAction = inMenu && !isSlaveUnit && isUsable && !isUnitInSlotbar(unit)
      actionFunc = @() takeUnitInSlotbar(unit, {
        unitObj = unitObj
        shouldCheckCrewsReady = shouldCheckCrewsReady
        cellClass = cellClass
      })
    }
    else if (action == "repair") {
      let repairCost = wp_get_repair_cost(unit.name)
      actionText = "".concat(loc("mainmenu/btnRepair"), ": ", Cost(repairCost).getTextAccordingToBalance())
      icon       = "#ui/gameuiskin#slot_repair.svg"
      haveWarning = true
      showAction = inMenu && !isSlaveUnit && isUsable && repairCost > 0 && canChangeCrewUnits()
      actionFunc = @() repairWithMsgBox(unit)
    }
    else if (action == "buy") {
      let isSpecial   = isUnitSpecial(unit)
      let isGift   = isUnitGift(unit)
      local canBuyOnline = canBuyUnitOnline(unit)
      let canBuyNotResearchedUnit = canBuyNotResearched(unit)
      let canBuyAfterPrevUnit = !isUnitUsable(unit) && !canBuyUnitOnMarketplace(unit)
        && (isSpecial || isUnitResearched(unit))
      let canBuyIngame = !canBuyOnline && (canBuyUnit(unit) || canBuyNotResearchedUnit || canBuyAfterPrevUnit)
      local forceShowBuyButton = false
      local priceText = ""

      if (canBuyIngame) {
        let price = canBuyNotResearchedUnit ? unit.getOpenCost() : getUnitCost(unit)
        priceText = price.getTextAccordingToBalance()
        if (priceText.len())
          priceText = "".concat(loc("ui/colon"), priceText)
      }

      actionText = "".concat(loc("mainmenu/btnOrder"), priceText)

      if (isGift && canUseIngameShop()) {
        if (getShopItemsTable().len() == 0) {
          
          
          
          canBuyOnline = false
        }
        else if (!unit.isBought() && unit.getEntitlements().map(
            @(id) getBundleId(id)
          ).filter(
            @(bundleId) bundleId != "" && getShopItem(bundleId) != null
          ).len() == 0) {
          actionText = loc("mainemnu/comingsoon")
          disabled = true
          forceShowBuyButton = true
        }
      }

      icon       = isGift ? (canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg"
                            : "#ui/gameuiskin#store_icon.svg")
                        : isSpecial || canBuyNotResearchedUnit ? "#ui/gameuiskin#shop_warpoints_premium.svg"
                            : "#ui/gameuiskin#shop_warpoints.svg"

      showAction = inMenu && !isSlaveUnit && !unit.isCrossPromo && (canBuyIngame || canBuyOnline || forceShowBuyButton) && !hasUnitEvent(unit.name)
      isLink     = !canUseIngameShop() && canBuyOnline
      if (canBuyOnline)
        actionFunc = @() showUnitGoods(unit.name, "unit_context_menu")
      else
        actionFunc = @() buyUnit(unit)
    }
    else if (action == "research") {
      if (isUnitResearched(unit))
        continue

      let isInResearch = isUnitInResearch(unit)
      let isSquadronVehicle = unit.isSquadronVehicle()
      let isInClan = is_in_clan()
      let reqExp = getUnitReqExp(unit) - getUnitExp(unit)
      let squadronExp = min(clan_get_exp(), reqExp)
      let canFlushSquadronExp = hasFeature("ClanVehicles") && isSquadronVehicle
        && squadronExp > 0
      if (isSquadronVehicle && isInClan && isInResearch && !canFlushSquadronExp && !needChosenResearchOfSquadron)
        continue

      let countryExp = shop_get_country_excess_exp(getUnitCountry(unit), getEsUnitType(unit))
      let getReqExp = reqExp < countryExp ? reqExp : countryExp
      let needToFlushExp = !isSquadronVehicle && shopResearchMode && countryExp > 0
      let squadronExpText = Cost().setSap(squadronExp).tostring()

      actionText = needToFlushExp || (isSquadronResearchMode && needChosenResearchOfSquadron)
        ? format("".concat(loc("mainmenu/btnResearch"),
          (needToFlushExp || canFlushSquadronExp ? " (%s)" : "")),
          isSquadronVehicle
            ? squadronExpText
            : Cost().setRp(getReqExp).tostring())
        : canFlushSquadronExp && (isInResearch || isSquadronResearchMode)
          ? format("".concat(loc("mainmenu/btnInvestSquadronExp"), " (%s)"), squadronExpText)
            : isInResearch && setResearchManually && !isSquadronVehicle
              ? loc("mainmenu/btnConvert")
              : loc("mainmenu/btnResearch")
      showAction = inMenu && !isSlaveUnit && (!isInResearch || hasFeature("SpendGold"))
        && (isUnitFeatureLocked(unit) || canResearchUnit(unit)
          || canFlushSquadronExp || (isSquadronVehicle && !is_in_clan()))
      disabled = !showAction
      actionFunc = needToFlushExp
        || (isSquadronResearchMode && (needChosenResearchOfSquadron || canFlushSquadronExp))
        ? function() { onSpendExcessExp?() }
        : canFlushSquadronExp && isInResearch
          ? function() { flushSquadronExp(unit) }
          : !setResearchManually
            ? function () { onCloseShop?() }
            : isInResearch && !isSquadronVehicle
              ? function () { gui_modal_convertExp(unit) }
              : function () {
                  if (!checkForResearch(unit))
                    return

                  research(unit)
                }
    }
    else if (action == "testflight" || action == "testflightforced") {
      let shouldSkipUnitCheck = action == "testflightforced"

      actionText = unit.unitType.getTestFlightText()
      icon       = unit.unitType.testFlightIcon
      showAction = inMenu && ::isTestFlightAvailable(unit, shouldSkipUnitCheck)
      actionFunc = function () {
        checkQueueAndStart(@() guiStartTestflight({ unit, shouldSkipUnitCheck }),
          null, "isCanNewflight")
      }
    }
    else if (action == "researchCrossPromo") {
      actionText = loc("sm_conditions")
      actionFunc = @() openCrossPromoWnd(unit.crossPromoBanner)
      showAction = inMenu && unit.isCrossPromo && !unit.isUsable()
    }
    else if (action == "info") {
      actionText = loc("mainmenu/btnAircraftInfo")
      icon       = "#ui/gameuiskin#btn_info.svg"
      showAction = !isSlaveUnit && isUnitDescriptionValid(unit)
      isLink     = hasFeature("WikiUnitInfo")
      actionFunc = function () {
        if (hasFeature("WikiUnitInfo"))
          openUrl(format(getCurCircuitOverride("wikiObjectsURL", loc("url/wiki_objects")), unit.name), false, false, "unit_actions")
        else
          showInfoMsgBox("".concat(colorize("activeTextColor", getUnitName(unit, false)), "\n", loc("profile/wiki_link")))
      }
    }
    else if (action == "find_in_market") {
      actionText = loc("msgbox/btn_find_on_marketplace")
      icon       = "#ui/gameuiskin#gc.svg"
      showAction = !isSlaveUnit && !hasUnitCoupon(unit.name) && canBuyUnitOnMarketplace(unit)
      isLink     = true
      actionFunc = function() {
        let item = findItemById(unit.marketplaceItemdefId)
        if (item && item.hasLink())
          item.openLink()
      }
    }
    else if (action == "use_coupon") {
      actionText = loc("item/consume/coupon")
      icon       = "#ui/gameuiskin#gc.svg"
      showAction = !isSlaveUnit && hasUnitCoupon(unit.name)
      actionFunc = function() {
        getUnitCoupon(unit.name).consume(null, null)
      }
    }
    else if (action == "changeUnitsGroup") {
      actionText = loc("mainmenu/changeUnitsGroup")
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      iconRotation = 90
      showAction = inMenu && !isSlaveUnit && hasSlotbarByUnitsGroups && crew != null && slotbar != null
      actionFunc = function () {
        checkQueueAndStart(
          function() {
            checkSquadUnreadyAndDo(
              @() selectGroupHandler.open(crew, slotbar),
              @() null, shouldCheckCrewsReady)
          }, null, "isCanModifyCrew")
      }
    }
    else if (action == "add_to_wishlist") {
      let isListFull = isWishlistFull()
      actionText = loc("mainmenu/add_to_wishlist")
      isWarning = isListFull
      icon       = "#ui/gameuiskin#add_to_wishlist.svg"
      showAction = !isSlaveUnit && hasFeature("Wishlist") && !hasInWishlist(unit.name) && !unit.isBought()
      actionFunc = @() isListFull ? showInfoMsgBox(colorize("activeTextColor", loc("wishlist/wishlist_full")))
        : addToWishlist(unit)
    }
    else if (action == "go_to_wishlist") {
      actionText = loc("mainmenu/go_to_wishlist")
      icon       = "#ui/gameuiskin#go_to_wishlist.svg"
      showAction = !isSlaveUnit && hasFeature("Wishlist") && hasInWishlist(unit.name) && !unit.isBought()
      actionFunc = @() openWishlist({ unitName = unit.name })
    }
    else if (action == "go_to_event") {
      actionText = loc("mainmenu/btnGotoAchievement")
      showAction = hasUnitEvent(unit.name)
      actionFunc = function() {
        let eventId = getUnitEventId(unit.name)
        guiStartProfile({ initialSheet = "UnlockAchievement", curAchievementGroupName = eventId })
      }
    }

    actions.append({
      actionName   = action
      action       = actionFunc
      text         = actionText
      show         = showAction
      disabled
      icon
      haveWarning
      haveDiscount
      isLink
      isObjective
      iconRotation
      isWarning
      isShowDragAndDropIcon
      dragAndDropIconHint = isShowDragAndDropIcon ? loc("slotbar/dragUnitHint") : null
    })
  }

  return actions
})

let showMenu = function showMenu(params) {
  if (params?.needClose) {
    let handler = handlersManager.findHandlerClassInScene(gui_handlers.ActionsList)
    handler?.close()
    if ((!showConsoleButtons.value || is_mouse_last_time_used()) && params?.unitObj)
      if (showConsoleButtons.value)
        delayedTooltipOnHover(params?.unitObj)
      else
        params.handler.guiScene.updateTooltip(params?.unitObj)
    unitContextMenuState(null)
    return
  }

  let actions = getActions(params, KWARG_NON_STRICT)  
  if (actions.len() == 0)
    return
  let listData = {
    handler = null
    needCloseTooltips = params?.needCloseTooltips ?? false
    closeOnUnhover = params?.closeOnUnhover ?? true
    onDeactivateCb = @() unitContextMenuState(null)
    actions = actions
    cssParams = {["min-width"] = "1@mainMenuButtonWidth"}
  }
  gui_handlers.ActionsList.open(params.unitObj, listData)
}

unitContextMenuState.subscribe(@(val) val != null ? showMenu(val) : null)

function onCloseActionsList(data) {
  if (unitContextMenuState.get()?.unitObj == null ||
    unitContextMenuState.get().unitObj != data.listParent)
    return
  unitContextMenuState(null)
}

addListenersWithoutEnv({
   ClosedActionsList = onCloseActionsList
})