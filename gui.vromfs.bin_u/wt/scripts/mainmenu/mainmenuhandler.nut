local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local contentStateModule = require("scripts/clientState/contentState.nut")
local { topMenuHandler } = require("scripts/mainmenu/topMenuStates.nut")

class ::gui_handlers.MainMenu extends ::gui_handlers.InstantDomination
{
  rootHandlerClass = ::gui_handlers.TopMenu

  onlyDevicesChoice    = true
  startControlsWizard  = false
  timeToAutoQuickMatch = 0.0
  timeToChooseCountry  = 0.0

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

    ::check_tutorial_reward()

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
    restoreFocus()
  }

  function onEventOnlineInfoUpdate(params)
  {
    showOnlineInfo()
  }

  function showOnlineInfo()
  {
    if (::is_vietnamese_version() || ::is_vendor_tencent() || topMenuHandler.value == null)
      return

    local text = ::loc("mainmenu/online_info", {
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
    local haveRights = ::g_clans.isHaveRightsToReviewCandidates()
    local isReqButtonDisplay = haveRights && ::g_clans.getMyClanCandidates().len() > 0
    local obj = showSceneBtn("btn_main_menu_showRequests", isReqButtonDisplay)
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
        ["yes", ::exit_game],
        ["no", function() { }]
      ], "no", { cancel_fn = function() {}})
  }

  function onProfileChange() {}  //changed country
  function activateSelectedBlock(obj) {}

  function onLoadModels()
  {
    if (::is_ps4_or_xbox)
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
    local lowQuality = !::is_loaded_model_high_quality()
    local warningObj = showSceneBtn("low-quality-model-warning", lowQuality)
    local canDownloadPackage = ::can_download_package()
    ::showBtn("low_quality_model_download_button", canDownloadPackage, warningObj)

    if (lowQuality && canDownloadPackage && isSceneActive() && ::isInMenu())
      ::check_package_and_ask_download_once("pkg_main", "air_in_hangar")
  }

  forceUpdateSelUnitInfo = @() updateSelUnitInfo(true)
  function updateSelUnitInfo(isForced = false)
  {
    local unitName = ::hangar_get_current_unit_name()
    if (!isForced && unitName == visibleUnitInfoName)
      return
    visibleUnitInfoName = unitName

    local unit = ::getAircraftByName(unitName)
    local lockObj = scene.findObject("crew-notready-topmenu")
    lockObj.tooltip = ::format(::loc("msgbox/no_available_aircrafts"),
      time.secondsToString(::get_warpoints_blk()?.lockTimeMaxLimitSec ?? 0))
    ::setCrewUnlockTime(lockObj, unit)

    updateUnitRentInfo(unit)
    updateLowQualityModelWarning()
  }

  function updateUnitRentInfo(unit)
  {
    local rentInfoObj = scene.findObject("rented_unit_info_text")
    local messageTemplate = ::loc("mainmenu/unitRentTimeleft") + ::loc("ui/colon") + "%s"
    SecondsUpdater(rentInfoObj, function(obj, params) {
      local isVisible = !!unit && unit.isRented()
      obj.show(isVisible)
      if (isVisible)
      {
        local sec = unit.getRentTimeleft()
        local hours = time.secondsToHours(sec)
        local timeStr = hours < 1.0 ?
          time.secondsToString(sec) :
          time.hoursToString(hours, false, true, true)
        obj.setValue(::format(messageTemplate, timeStr))
      }
      return !isVisible
    })
  }
}