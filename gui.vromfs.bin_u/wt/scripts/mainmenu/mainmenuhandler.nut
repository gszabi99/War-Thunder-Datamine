let SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
let time = require("scripts/time.nut")
let contentStateModule = require("scripts/clientState/contentState.nut")
let topMenuHandlerClass = require("scripts/mainmenu/topMenuHandler.nut")
let { topMenuHandler } = require("scripts/mainmenu/topMenuStates.nut")
let exitGame = require("scripts/utils/exitGame.nut")
let { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
let { tryOpenTutorialRewardHandler } = require("scripts/tutorials/tutorialRewardHandler.nut")
let { getCrewUnlockTime } = require("scripts/crew/crewInfo.nut")
let { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

::gui_handlers.MainMenu <- class extends ::gui_handlers.InstantDomination
{
  rootHandlerClass = topMenuHandlerClass.getHandler()

  unitInfoPanel = null
  promoHandler = null

  visibleUnitInfoName = ""

  //custom functions
  function initScreen()
  {
    ::set_presence_to_player("menu")
    ::enableHangarControls(true)

    if (::g_login.isAuthorized())
      base.initScreen()

    tryOpenTutorialRewardHandler()

    forceUpdateSelUnitInfo()

    if (::g_login.isAuthorized())
    {
      showOnlineInfo()
      updateClanRequests()
    }

    if (::SessionLobby.isInRoom())
    {
      dagor.debug("after main menu, uid " + ::my_user_id_str + ", " + ::my_user_name + " is in room")
      ::callstack()
      ::SessionLobby.leaveRoom()
    }
    ::stop_gui_sound("deb_count") //!!Dirty hack: after inconsistent leave debriefing from code.
  }

  function onEventOnlineInfoUpdate(params)
  {
    showOnlineInfo()
  }

  function showOnlineInfo()
  {
    if (::is_vietnamese_version() || ::is_vendor_tencent() || topMenuHandler.value == null)
      return

    let text = ::loc("mainmenu/online_info", {
      playersOnline = ::online_stats.players_total,
      battles = ::online_stats.rooms_total
    })

    setSceneTitle(text, topMenuHandler.value.scene, "online_info")
  }

  function onEventClanInfoUpdate(params)
  {
    updateClanRequests()
  }

  function updateClanRequests()
  {
    let haveRights = ::g_clans.isHaveRightsToReviewCandidates()
    let isReqButtonDisplay = haveRights && ::g_clans.getMyClanCandidates().len() > 0
    let obj = showSceneBtn("btn_main_menu_showRequests", isReqButtonDisplay)
    if (::checkObj(obj) && isReqButtonDisplay)
      obj.setValue(::loc("clan/btnShowRequests") + ::loc("ui/parentheses/space",
        {text = ::g_clans.getMyClanCandidates().len()}))
  }

  function onExit()
  {
    if (!::is_platform_pc && !::is_platform_android)
      return

    msgBox("mainmenu_question_quit_game", ::loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGame],
        ["no", function() { }]
      ], "no", { cancel_fn = function() {}})
  }

  function onLoadModels()
  {
    if (isPlatformSony || isPlatformXboxOne)
      showInfoMsgBox(contentStateModule.getClientDownloadProgressText())
    else
      ::check_package_and_ask_download("pkg_main", ::loc("msgbox/ask_package_download"))
  }

  function initPromoBlock()
  {
    if (promoHandler != null)
      return
    if (!::has_feature("PromoBlocks"))
      return

    promoHandler = ::create_promo_blocks(this)
    registerSubHandler(promoHandler)
  }

  function onEventHangarModelLoading(p)
  {
    doWhenActiveOnce("updateSelUnitInfo")
  }

  function onEventHangarModelLoaded(p)
  {
    doWhenActiveOnce("forceUpdateSelUnitInfo")
  }

  function onEventCrewsListChanged(p)
  {
    doWhenActiveOnce("forceUpdateSelUnitInfo")
  }

  function updateLowQualityModelWarning()
  {
    let lowQuality = !::is_loaded_model_high_quality()
    let warningObj = showSceneBtn("low-quality-model-warning", lowQuality)
    let canDownloadPackage = ::can_download_package()
    ::showBtn("low_quality_model_download_button", canDownloadPackage, warningObj)

    if (lowQuality && canDownloadPackage && isSceneActive() && ::isInMenu())
      ::check_package_and_ask_download_once("pkg_main", "air_in_hangar")
  }

  forceUpdateSelUnitInfo = @() updateSelUnitInfo(true)
  function updateSelUnitInfo(isForced = false)
  {
    let unitName = ::hangar_get_current_unit_name()
    if (!isForced && unitName == visibleUnitInfoName)
      return
    visibleUnitInfoName = unitName

    let unit = ::getAircraftByName(unitName)
    updateUnitCrewLocked(unit)
    updateUnitRentInfo(unit)
    updateLowQualityModelWarning()
  }

  function updateUnitRentInfo(unit)
  {
    let rentInfoObj = scene.findObject("rented_unit_info_text")
    let messageTemplate = ::loc("mainmenu/unitRentTimeleft") + ::loc("ui/colon") + "%s"
    SecondsUpdater(rentInfoObj, function(obj, params) {
      let isVisible = !!unit && unit.isRented()
      obj.show(isVisible)
      if (isVisible)
      {
        let sec = unit.getRentTimeleft()
        let hours = time.secondsToHours(sec)
        let timeStr = hours < 1.0 ?
          time.secondsToString(sec) :
          time.hoursToString(hours, false, true, true)
        obj.setValue(::format(messageTemplate, timeStr))
      }
      return !isVisible
    })
  }

  function updateUnitCrewLocked(unit) {
    let lockObj = scene.findObject("crew-notready-topmenu")
    lockObj.tooltip = ::format(::loc("msgbox/no_available_aircrafts"),
      time.secondsToString(::get_warpoints_blk()?.lockTimeMaxLimitSec ?? 0))

    local wasShown = false
    SecondsUpdater(lockObj, function(obj, params) {
      let crew = unit != null ? ::getCrewByAir(unit) : null
      let unlockTime = crew != null ? getCrewUnlockTime(crew) : 0
      obj.show(unlockTime > 0)
      if (unlockTime <= 0) {
        if (wasShown) {
          ::g_crews_list.invalidate()
          obj.getScene().performDelayed(this, function() { ::reinitAllSlotbars() })
        }
        return true
      }

      wasShown = true
      let timeStr = time.secondsToString(unlockTime)
      obj.findObject("time").setValue(timeStr)

      let showButtons = ::has_feature("EarlyExitCrewUnlock")
      let crewCost = ::shop_get_unlock_crew_cost(crew.id)
      let crewCostGold = ::shop_get_unlock_crew_cost_gold(crew.id)
      if (showButtons)
      {
        placePriceTextToButton(obj, "btn_unlock_crew", ::loc("mainmenu/btn_crew_unlock"), crewCost, 0)
        placePriceTextToButton(obj, "btn_unlock_crew_gold", ::loc("mainmenu/btn_crew_unlock"), 0, crewCostGold)
      }
      ::showBtnTable(obj, {
        btn_unlock_crew = showButtons && crewCost > 0
        btn_unlock_crew_gold = showButtons && crewCostGold > 0
        crew_unlock_buttons = showButtons && (crewCost > 0 || crewCostGold > 0)
      })
      return false
    })
  }
}