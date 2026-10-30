import "%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut" as slotbarPresets
import "%scripts/unit/unitContextMenuState.nut" as unitContextMenuState
import "%scripts/slotbar/selectUnitHandler.nut" as selectUnitHandler
import "%scripts/slotbar/selectGroupHandler.nut" as selectGroupHandler
import "%scripts/crew/crewModalByVehiclesGroups.nut" as crewModalByVehiclesGroups
import "%scripts/weaponry/guiStartWeaponryPresets.nut" as guiStartWeaponryPresets
import "%scripts/openCrossPromoWnd.nut" as openCrossPromoWnd
import "%scripts/unit/takeUnitInSlotbar.nut" as takeUnitInSlotbar
from "%scripts/user/profileHandler.nut" import Profile, guiStartProfile
from "%scripts/actionsList.nut" import ActionsList
from "%scripts/money.nut" import Cost
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import is_in_loading_screen
from "%scripts/onlineShop/entitlementsShopData.nut" import getShopItem, canUseIngameShop, getShopItemsTable
from "%scripts/unit/unitActions.nut" import repairWithMsgBox, flushSquadronExp, buyUnit, research
from "%scripts/onlineShop/onlineBundles.nut" import getBundleId
from "%scripts/weaponry/weaponryInfo.nut" import checkUnitWeapons, checkUnitSecondaryWeapons, needSecondaryWeaponsWnd
from "%scripts/unit/unitStatus.nut" import canBuyNotResearched, canResearchUnit, isUnitInResearch, canShowUnitInfo, isUnitUsable, isUnitFeatureLocked, isUnitResearched, isTestFlightAvailable
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitInSlotbar
from "%scripts/unit/unitWeaponryInfo.nut" import isUnitHaveSecondaryWeapons
from "%scripts/unit/unitChecks.nut" import checkForResearch
from "%scripts/slotbar/playerCurUnit.nut" import showedUnit
from "%scripts/unlocks/unlockMarkers.nut" import getUnlockIdByUnitName, hasMarkerByUnitName
from "%scripts/unit/unitInfo.nut" import getUnitCountry, getUnitReqExp, getUnitExp, getUnitCost
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/unit/unitShopInfo.nut" import canBuyUnit, isUnitGift
from "%scripts/squads/squadUtils.nut" import checkSquadUnreadyAndDo
from "%scripts/missions/modificationTutorial.nut" import needShowUnseenModTutorialForUnit
from "%scripts/onlineShop/onlineShopModel.nut" import showUnitGoods
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/customization/contentPreview.nut" import gui_start_decals, guiStartInfantryCamouflage
from "%scripts/missionBuilder/testFlightState.nut" import guiStartTestflight
from "%scripts/wishlist/wishlistManager.nut" import hasInWishlist, isWishlistFull, canAddUnitToWishlist
from "%scripts/wishlist/addWishWnd.nut" import tryAddToWishlist
from "%scripts/crew/crewDiscount.nut" import getCrewMaxDiscountByInfo, getCrewDiscountInfo
from "%scripts/wishlist/wishlistHandler.nut" import openWishlist
from "%scripts/crew/crew.nut" import isCrewNeedUnseenIcon, gui_modal_crew
from "%scripts/unit/unitWikiInfo.nut" import openUnitWikiInfo
from "%scripts/items/unitCoupons.nut" import getUnitCoupon, hasUnitCoupon
from "%scripts/discounts/discountUtils.nut" import getMaxWeaponryDiscountByUnitName
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/crew/crewInfo.nut" import getCrewByAir
from "%scripts/weaponry/weaponryActions.nut" import open_weapons_for_unit
from "%scripts/matchingRooms/sessionLobbyState.nut" import canChangeCrewUnits
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "%scripts/utils/delayedTooltip.nut" import delayedTooltipOnHover
from "%scripts/convertExp/convertExp.nut" import openConvertExpModalWnd
from "%scripts/unit/canBuyUnitOnMarketplace.nut" import canBuyUnitOnMarketplace
from "%scripts/unit/availabilityBuyOnline.nut" import canBuyUnitOnline
from "%scripts/unit/unitEvents.nut" import hasUnitEvent, getUnitEventId, isUnitOnlyFromEvent
from "%scripts/customization/infantryCamouflageStorage.nut" import getSkinsSeenList
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "string" import format
from "%sqstd/functools.nut" import KWARG_NON_STRICT
from "%scripts/dagui_natives.nut" import clan_get_exp, shop_get_country_excess_exp, wp_get_repair_cost, is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/clans/clanState.nut" import is_in_clan

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

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
          showedUnit.set(unit)
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
      actionFunc = @() loadHandler(Profile, {
        initialSheet = "UnlockAchievement"
        initialUnlockId = getUnlockIdByUnitName(unit.name, curEdiff)
      })
    }
    else if (action == "weapons") {
      actionText = loc("mainmenu/btnWeapons")
      icon       = "#ui/gameuiskin#btn_weapons.svg"
      haveWarning = checkUnitWeapons(unit, true) != UNIT_WEAPONS_READY
        || needShowUnseenModTutorialForUnit(unit)
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

      showAction = inMenu && !isSlaveUnit && !unit.isCrossPromo
        && (canBuyIngame || canBuyOnline || forceShowBuyButton)
        && !isUnitOnlyFromEvent(unit)
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
              ? function () { openConvertExpModalWnd(unit) }
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
      showAction = inMenu && isTestFlightAvailable(unit, shouldSkipUnitCheck)
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
      showAction = canShowUnitInfo(unit)
      isLink     = hasFeature("WikiUnitInfo")
      actionFunc = @() openUnitWikiInfo(unit, "unit_actions")
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
      actionText = loc("mainmenu/add_to_wishlist")
      isWarning = isWishlistFull()
      icon       = "#ui/gameuiskin#add_to_wishlist.svg"
      showAction = canAddUnitToWishlist(unit)
      actionFunc = @() tryAddToWishlist(unit)
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
    else if (action == "infantry_camouflage") {
      actionText = loc("infantry_camouflage")
      icon       = "#ui/gameuiskin#slot_showroom.svg"
      showAction = inMenu && unit.isHuman()
      haveWarning = showAction && getSkinsSeenList().hasUnseenItems()
      actionFunc = function () {
        checkQueueAndStart(function () {
          broadcastEvent("BeforeStartShowroom")
          showedUnit.set(unit)
          handlersManager.animatedSwitchScene(guiStartInfantryCamouflage)
        }, null, "isCanModifyCrew")
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
    let handler = handlersManager.findHandlerClassInScene(ActionsList)
    handler?.close()
    if ((!showConsoleButtons.get() || is_mouse_last_time_used()) && params?.unitObj.isValid())
      if (showConsoleButtons.get())
        delayedTooltipOnHover(params?.unitObj)
      else
        params.handler.guiScene.updateTooltip(params?.unitObj)
    unitContextMenuState.set(null)
    return
  }

  let actions = getActions(params, KWARG_NON_STRICT)  
  if (actions.len() == 0)
    return
  let listData = {
    handler = null
    needCloseTooltips = params?.needCloseTooltips ?? false
    closeOnUnhover = params?.closeOnUnhover ?? true
    onDeactivateCb = @() unitContextMenuState.set(null)
    actions = actions
    cssParams = {["min-width"] = "1@mainMenuButtonWidth"}
  }
  ActionsList.open(params.unitObj, listData)
}

unitContextMenuState.subscribe(@(val) val != null ? showMenu(val) : null)

function onCloseActionsList(data) {
  if (unitContextMenuState.get()?.unitObj == null ||
    unitContextMenuState.get().unitObj != data.listParent)
    return
  unitContextMenuState.set(null)
}

addListenersWithoutEnv({
   ClosedActionsList = onCloseActionsList
})