from "%scripts/dagui_natives.nut" import stop_gui_sound, set_presence_to_player, shop_get_unlock_crew_cost, shop_get_unlock_crew_cost_gold
from "%scripts/dagui_library.nut" import *
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { debug_dump_stack } = require("dagor.debug")
let { hangar_get_current_unit_name } = require("hangar")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let contentStateModule = require("%scripts/clientState/contentState.nut")
let topMenuHandlerClass = require("%scripts/mainmenu/topMenuHandler.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { tryOpenTutorialRewardHandler } = require("%scripts/tutorials/tutorialRewardHandler.nut")
let { getCrewUnlockTime, getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getSuggestedSkin } = require("%scripts/customization/suggestedSkins.nut")
let { startFleetTrainingMission, canStartFleetTrainingMission
} = require("%scripts/missions/fleetTrainingMission.nut")
let { create_promo_blocks } = require("%scripts/promo/promoHandler.nut")
let { get_warpoints_blk } = require("blkGetters")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userName, userIdStr } = require("%scripts/user/profileStates.nut")
let { getCrewUnlockTimeByUnit } = require("%scripts/slotbar/slotbarState.nut")
let { invalidateCrewsList, reinitAllSlotbars } = require("%scripts/slotbar/crewsList.nut")
let { checkPackageAndAskDownloadOnce } = require("%scripts/clientState/contentPacks.nut")
let { isAuthorized } = require("%scripts/login/loginStates.nut")

gui_handlers.MainMenu <- class (gui_handlers.InstantDomination) {
  rootHandlerClass = topMenuHandlerClass.getHandler()

  unitInfoPanel = null
  promoHandler = null

  visibleUnitInfoName = ""

  //custom functions
  function initScreen() {
    set_presence_to_player("menu")

    if (isAuthorized.get())
      base.initScreen()

    tryOpenTutorialRewardHandler()

    this.forceUpdateSelUnitInfo()

    if (isAuthorized.get()) {
      this.showOnlineInfo()
      this.updateClanRequests()
    }

    if (isInSessionRoom.get()) {
      log(" ".concat("after main menu, uid", userIdStr.value, userName.value, "is in room"))
      debug_dump_stack()
      ::SessionLobby.leaveRoom()
    }
    stop_gui_sound("deb_count") //!!Dirty hack: after inconsistent leave debriefing from code.
  }

  function onStart() {
    if (canStartFleetTrainingMission()) {
      this.guiScene.performDelayed(this, @() this.goForward(startFleetTrainingMission))
      return
    }
    base.onStart()
  }

  function onEventOnlineInfoUpdate(_params) {
    this.showOnlineInfo()
  }

  function showOnlineInfo() {
    if (topMenuHandler.value == null)
      return

    let text = loc("mainmenu/online_info", {
      playersOnline = ::online_stats.players_total,
      battles = ::online_stats.rooms_total
    })

    this.setSceneTitle(text, topMenuHandler.value.scene, "online_info")
  }

  function onEventClanInfoUpdate(_params) {
    this.updateClanRequests()
  }

  function updateClanRequests() {
    let haveRights = ::g_clans.isHaveRightsToReviewCandidates()
    let isReqButtonDisplay = haveRights && ::g_clans.getMyClanCandidates().len() > 0
    let obj = showObjById("btn_main_menu_showRequests", isReqButtonDisplay, this.scene)
    if (checkObj(obj) && isReqButtonDisplay)
      obj.setValue("".concat(
        loc("clan/btnShowRequests"),
        loc("ui/parentheses/space",
          { text = ::g_clans.getMyClanCandidates().len() })))
  }

  function onExit() {
    if (!is_platform_pc && !is_platform_android)
      return

    this.msgBox("mainmenu_question_quit_game", loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no", function() { }]
      ], "no", { cancel_fn = function() {} })
  }

  function onLoadModels() {
    if (isPlatformSony || isPlatformXboxOne)
      showInfoMsgBox(contentStateModule.getClientDownloadProgressText())
    else
      ::check_package_and_ask_download("pkg_main", loc("msgbox/ask_package_download"))
  }

  function initPromoBlock() {
    if (this.promoHandler != null)
      return
    if (!hasFeature("PromoBlocks"))
      return

    this.promoHandler = create_promo_blocks(this)
    this.registerSubHandler(this.promoHandler)
  }

  function onEventHangarModelLoading(_p) {
    this.doWhenActiveOnce("updateSelUnitInfo")
  }

  function onEventHangarModelLoaded(_p) {
    this.doWhenActiveOnce("forceUpdateSelUnitInfo")
  }

  function onEventCrewsListChanged(_p) {
    this.doWhenActiveOnce("forceUpdateSelUnitInfo")
  }

  function updateLowQualityModelWarning() {
    let lowQuality = !::is_loaded_model_high_quality()
    showObjById("low-quality-model-warning", lowQuality, this.scene)
    if (lowQuality && this.isSceneActive() && isInMenu())
      checkPackageAndAskDownloadOnce("pkg_main", "air_in_hangar")
  }

  forceUpdateSelUnitInfo = @() this.updateSelUnitInfo(true)
  function updateSelUnitInfo(isForced = false) {
    let unitName = hangar_get_current_unit_name()
    if (!isForced && unitName == this.visibleUnitInfoName)
      return
    this.visibleUnitInfoName = unitName

    let unit = getAircraftByName(unitName)
    this.updateUnitCrewLocked(unit)
    this.updateUnitRentInfo(unit)
    this.updateLowQualityModelWarning()
    this.updateSuggestedSkin(unit)
  }

  function updateSuggestedSkin(unit) {
    local isVisible = unit != null
      && !unit.isRented()
      && getCrewUnlockTimeByUnit(unit) <= 0
    if (!isVisible) {
      showObjById("suggested_skin", isVisible, this.scene)
      return
    }

    let skin = getSuggestedSkin(unit.name)
    isVisible = skin?.canPreview() ?? false
    let containerObj = showObjById("suggested_skin", isVisible, this.scene)
    if (!isVisible)
      return

    containerObj.findObject("info_text").setValue(
      loc("suggested_skin/available", {
        skinName = skin.decoratorType.getLocName(skin.id) }))
  }

  function onSkinPreview() {
    getSuggestedSkin(hangar_get_current_unit_name())?.doPreview()
  }

  function updateUnitRentInfo(unit) {
    let rentInfoObj = this.scene.findObject("rented_unit_info_text")
    let messageTemplate = "".concat(loc("mainmenu/unitRentTimeleft"), loc("ui/colon"), "%s")
    SecondsUpdater(rentInfoObj, function(obj, _params) {
      let isVisible = !!unit && unit.isRented()
      obj.show(isVisible)
      if (isVisible) {
        let sec = unit.getRentTimeleft()
        let hours = time.secondsToHours(sec)
        let timeStr = hours < 1.0 ?
          time.secondsToString(sec) :
          time.hoursToString(hours, false, true, true)
        obj.setValue(format(messageTemplate, timeStr))
      }
      return !isVisible
    })
  }

  function updateUnitCrewLocked(unit) {
    let lockObj = this.scene.findObject("crew-notready-topmenu")
    lockObj.tooltip = format(loc("msgbox/no_available_aircrafts"),
      time.secondsToString(get_warpoints_blk()?.lockTimeMaxLimitSec ?? 0))

    local wasShown = false
    SecondsUpdater(lockObj, function(obj, _params) {
      let crew = unit != null ? getCrewByAir(unit) : null
      let unlockTime = crew != null ? getCrewUnlockTime(crew) : 0
      obj.show(unlockTime > 0)
      if (unlockTime <= 0) {
        if (wasShown) {
          invalidateCrewsList()
          obj.getScene().performDelayed(this, function() { reinitAllSlotbars() })
        }
        return true
      }

      wasShown = true
      let timeStr = time.secondsToString(unlockTime)
      obj.findObject("time").setValue(timeStr)

      let showButtons = hasFeature("EarlyExitCrewUnlock")
      let crewCost = shop_get_unlock_crew_cost(crew.id)
      let crewCostGold = shop_get_unlock_crew_cost_gold(crew.id)
      if (showButtons) {
        placePriceTextToButton(obj, "btn_unlock_crew", loc("mainmenu/btn_crew_unlock"), crewCost, 0)
        placePriceTextToButton(obj, "btn_unlock_crew_gold", loc("mainmenu/btn_crew_unlock"), 0, crewCostGold)
      }
      showObjectsByTable(obj, {
        btn_unlock_crew = showButtons && crewCost > 0
        btn_unlock_crew_gold = showButtons && crewCostGold > 0
        crew_unlock_buttons = showButtons && (crewCost > 0 || crewCostGold > 0)
      })
      return false
    })
  }

  function onEventItemsShopUpdate(_) {
    this.updateSuggestedSkin(getAircraftByName(hangar_get_current_unit_name()))
  }
}