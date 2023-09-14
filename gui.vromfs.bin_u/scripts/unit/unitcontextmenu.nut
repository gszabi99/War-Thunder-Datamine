//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")

let { format } = require("string")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getShopItem,
        canUseIngameShop,
        getShopItemsTable } = require("%scripts/onlineShop/entitlementsStore.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let selectUnitHandler = require("%scripts/slotbar/selectUnitHandler.nut")
let selectGroupHandler = require("%scripts/slotbar/selectGroupHandler.nut")
let crewModalByVehiclesGroups = require("%scripts/crew/crewModalByVehiclesGroups.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let weaponryPresetsModal = require("%scripts/weaponry/weaponryPresetsModal.nut")
let { checkUnitWeapons, checkUnitSecondaryWeapons,
        needSecondaryWeaponsWnd } = require("%scripts/weaponry/weaponryInfo.nut")
let { canBuyNotResearched, isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitStatus.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getUnlockIdByUnitName, hasMarkerByUnitName } = require("%scripts/unlocks/unlockMarkers.nut")
let { KWARG_NON_STRICT } = require("%sqstd/functools.nut")
let openCrossPromoWnd = require("%scripts/openCrossPromoWnd.nut")
let { getEsUnitType, getUnitName } = require("%scripts/unit/unitInfo.nut")

let getActions = kwarg(function getActions(unitObj, unit, actionsNames, crew = null, curEdiff = -1,
  isSlotbarEnabled = true, setResearchManually = null, needChosenResearchOfSquadron = false,
  isSquadronResearchMode = false, hasSlotbarByUnitsGroups = false, shopResearchMode = false,
  shouldCheckCrewsReady = false, onSpendExcessExp = null, onCloseShop = null, slotbar = null
) {
  let actions = []
  if (!unit || ("airsGroup" in unit) || actionsNames.len() == 0 || ::is_in_loading_screen())
    return actions

  let inMenu = ::isInMenu()
  let isUsable  = unit.isUsable()
  crew = crew ?? (hasSlotbarByUnitsGroups ? slotbarPresets.getCrewByUnit(unit) : ::getCrewByAir(unit))

  foreach (action in actionsNames) {
    local actionText = ""
    local showAction = false
    local actionFunc = null
    local haveWarning  = false
    local haveDiscount = false
    local disabled    = false
    local icon       = ""
    local isLink = false
    local iconRotation = 0
    local isObjective = false

    if (action == "showroom") {
      actionText = loc(isUsable ? "mainmenu/btnShowroom" : "mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#slot_showroom.svg"
      showAction = inMenu
      actionFunc = function () {
        ::queues.checkAndStart(function () {
          broadcastEvent("BeforeStartShowroom")
          showedUnit(unit)
          handlersManager.animatedSwitchScene(::gui_start_decals)
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
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      showAction = inMenu && ::SessionLobby.canChangeCrewUnits()
      actionFunc = function () {
        ::queues.checkAndStart(
          function() {
            ::g_squad_utils.checkSquadUnreadyAndDo(
              @() selectUnitHandler.open(crew, slotbar),
              @() null, shouldCheckCrewsReady)
          }, null, "isCanModifyCrew")
      }
    }
    else if (action == "crew") {
      if (crew == null)
        continue

      let discountInfo = ::g_crew.getDiscountInfo(crew.idCountry, crew.idInCountry)

      actionText = loc("mainmenu/btnCrew")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      haveWarning = isInArray(::get_crew_status(crew, unit), [ "ready", "full" ])
      haveDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo) > 0
      showAction = inMenu
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
          ::gui_modal_crew(params)
      }
    }
    else if (action == "sec_weapons") {
      actionText = loc("options/secondary_weapons")
      icon       = "#ui/gameuiskin#slot_preset.svg"
      haveWarning = checkUnitSecondaryWeapons(unit) != UNIT_WEAPONS_READY
      haveDiscount = ::get_max_weaponry_discount_by_unitName(unit.name, ["weapons"]) > 0
      showAction = inMenu &&
        needSecondaryWeaponsWnd(unit) && isUnitHaveSecondaryWeapons(unit)
      actionFunc = @() weaponryPresetsModal.open({
        unit = unit
        curEdiff = curEdiff
      })
    }
    else if (action == "goto_unlock") {
      if (hasSlotbarByUnitsGroups || !hasMarkerByUnitName(unit.name, curEdiff))
        continue

      actionText = loc("sm_objective")
      icon = "#ui/gameuiskin#sh_unlockachievement.svg"
      showAction = inMenu
      isObjective = true
      actionFunc = @() ::gui_start_profile({
        initialSheet = "UnlockAchievement"
        initialUnlockId = getUnlockIdByUnitName(unit.name, curEdiff)
      })
    }
    else if (action == "weapons") {
      actionText = loc("mainmenu/btnWeapons")
      icon       = "#ui/gameuiskin#btn_weapons.svg"
      haveWarning = checkUnitWeapons(unit, true) != UNIT_WEAPONS_READY
      haveDiscount = ::get_max_weaponry_discount_by_unitName(unit.name) > 0
      showAction = inMenu
      actionFunc = @() ::open_weapons_for_unit(unit, {
        curEdiff = curEdiff
        needHideSlotbar = !isSlotbarEnabled
      })
    }
    else if (action == "take") {
      actionText = loc("mainmenu/btnTakeAircraft")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      showAction = inMenu && isUsable && !::isUnitInSlotbar(unit)
      actionFunc = @() unitActions.take(unit, {
        unitObj = unitObj
        shouldCheckCrewsReady = shouldCheckCrewsReady
      })
    }
    else if (action == "repair") {
      let repairCost = ::wp_get_repair_cost(unit.name)
      actionText = loc("mainmenu/btnRepair") + ": " + Cost(repairCost).getTextAccordingToBalance()
      icon       = "#ui/gameuiskin#slot_repair.svg"
      haveWarning = true
      showAction = inMenu && isUsable && repairCost > 0 && ::SessionLobby.canChangeCrewUnits()
      actionFunc = @() unitActions.repairWithMsgBox(unit)
    }
    else if (action == "buy") {
      let isSpecial   = ::isUnitSpecial(unit)
      let isGift   = ::isUnitGift(unit)
      local canBuyOnline = ::canBuyUnitOnline(unit)
      let canBuyNotResearchedUnit = canBuyNotResearched(unit)
      let canBuyAfterPrevUnit = !::isUnitUsable(unit) && !::canBuyUnitOnMarketplace(unit)
        && (isSpecial || ::isUnitResearched(unit))
      let canBuyIngame = !canBuyOnline && (::canBuyUnit(unit) || canBuyNotResearchedUnit || canBuyAfterPrevUnit)
      local forceShowBuyButton = false
      local priceText = ""

      if (canBuyIngame) {
        let price = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
        priceText = price.getTextAccordingToBalance()
        if (priceText.len())
          priceText = loc("ui/colon") + priceText
      }

      actionText = loc("mainmenu/btnOrder") + priceText

      if (isGift && canUseIngameShop()) {
        if (getShopItemsTable().len() == 0) {
          //Override for ingameShop.
          //There is rare posibility, that shop data is empty.
          //Because of external error.
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

      showAction = inMenu && !unit.isCrossPromo && (canBuyIngame || canBuyOnline || forceShowBuyButton)
      isLink     = !canUseIngameShop() && canBuyOnline
      if (canBuyOnline)
        actionFunc = @() ::OnlineShopModel.showUnitGoods(unit.name, "unit_context_menu")
      else
        actionFunc = @() ::buyUnit(unit)
    }
    else if (action == "research") {
      if (::isUnitResearched(unit))
        continue

      let isInResearch = ::isUnitInResearch(unit)
      let isSquadronVehicle = unit.isSquadronVehicle()
      let isInClan = ::is_in_clan()
      let reqExp = ::getUnitReqExp(unit) - ::getUnitExp(unit)
      let squadronExp = min(::clan_get_exp(), reqExp)
      let canFlushSquadronExp = hasFeature("ClanVehicles") && isSquadronVehicle
        && squadronExp > 0
      if (isSquadronVehicle && isInClan && isInResearch && !canFlushSquadronExp && !needChosenResearchOfSquadron)
        continue

      let countryExp = ::shop_get_country_excess_exp(::getUnitCountry(unit), getEsUnitType(unit))
      let getReqExp = reqExp < countryExp ? reqExp : countryExp
      let needToFlushExp = !isSquadronVehicle && shopResearchMode && countryExp > 0
      let squadronExpText = Cost().setSap(squadronExp).tostring()

      actionText = needToFlushExp || (isSquadronResearchMode && needChosenResearchOfSquadron)
        ? format(loc("mainmenu/btnResearch")
          + (needToFlushExp || canFlushSquadronExp ? " (%s)" : ""),
          isSquadronVehicle
            ? squadronExpText
            : Cost().setRp(getReqExp).tostring())
        : canFlushSquadronExp && (isInResearch || isSquadronResearchMode)
          ? format(loc("mainmenu/btnInvestSquadronExp") + " (%s)", squadronExpText)
            : isInResearch && setResearchManually && !isSquadronVehicle
              ? loc("mainmenu/btnConvert")
              : loc("mainmenu/btnResearch")
      showAction = inMenu && (!isInResearch || hasFeature("SpendGold"))
        && (::isUnitFeatureLocked(unit) || ::canResearchUnit(unit)
          || canFlushSquadronExp || (isSquadronVehicle && !::is_in_clan()))
      disabled = !showAction
      actionFunc = needToFlushExp
        || (isSquadronResearchMode && (needChosenResearchOfSquadron || canFlushSquadronExp))
        ? function() { onSpendExcessExp?() }
        : canFlushSquadronExp && isInResearch
          ? function() { unitActions.flushSquadronExp(unit) }
          : !setResearchManually
            ? function () { onCloseShop?() }
            : isInResearch && !isSquadronVehicle
              ? function () { ::gui_modal_convertExp(unit) }
              : function () {
                  if (!::checkForResearch(unit))
                    return

                  unitActions.research(unit)
                }
    }
    else if (action == "testflight" || action == "testflightforced") {
      let shouldSkipUnitCheck = action == "testflightforced"

      actionText = unit.unitType.getTestFlightText()
      icon       = unit.unitType.testFlightIcon
      showAction = inMenu && ::isTestFlightAvailable(unit, shouldSkipUnitCheck)
      actionFunc = function () {
        ::queues.checkAndStart(@() ::gui_start_testflight({ unit, shouldSkipUnitCheck }),
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
      showAction = ::isUnitDescriptionValid(unit)
      isLink     = hasFeature("WikiUnitInfo")
      actionFunc = function () {
        if (hasFeature("WikiUnitInfo"))
          openUrl(format(loc("url/wiki_objects"), unit.name), false, false, "unit_actions")
        else
          showInfoMsgBox(colorize("activeTextColor", getUnitName(unit, false)) + "\n" + loc("profile/wiki_link"))
      }
    }
    else if (action == "find_in_market") {
      actionText = loc("msgbox/btn_find_on_marketplace")
      icon       = "#ui/gameuiskin#gc.svg"
      showAction = ::canBuyUnitOnMarketplace(unit)
      isLink     = true
      actionFunc = function() {
        let item = ::ItemsManager.findItemById(unit.marketplaceItemdefId)
        if (item && item.hasLink())
          item.openLink()
      }
    }
    else if (action == "changeUnitsGroup") {
      actionText = loc("mainmenu/changeUnitsGroup")
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      iconRotation = 90
      showAction = inMenu && hasSlotbarByUnitsGroups && crew != null && slotbar != null
      actionFunc = function () {
        ::queues.checkAndStart(
          function() {
            ::g_squad_utils.checkSquadUnreadyAndDo(
              @() selectGroupHandler.open(crew, slotbar),
              @() null, shouldCheckCrewsReady)
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
    })
  }

  return actions
})

let showMenu = function showMenu(params) {
  if (params == null) {
    handlersManager.findHandlerClassInScene(gui_handlers.ActionsList)?.close()
    return
  }

  let actions = getActions(params, KWARG_NON_STRICT)  // warning disable: -param-count
  if (actions.len() == 0)
    return

  gui_handlers.ActionsList.open(params.unitObj, {
    handler = null
    closeOnUnhover = params?.closeOnUnhover ?? true
    onDeactivateCb = @() unitContextMenuState(null)
    actions = actions
  })
}

unitContextMenuState.subscribe(function (v) {
    showMenu(v)
})

addListenersWithoutEnv({
  ClosedUnitItemMenu = @(_p) unitContextMenuState(null)
})

return showMenu
