let crossplayModule = require("scripts/social/crossplay.nut")
let mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
let slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { openUrl } = require("scripts/onlineShop/url.nut")
let { isPlatformSony, targetPlatform } = require("scripts/clientState/platform.nut")
let { getMyCrewUnitsState } = require("scripts/slotbar/crewsListInfo.nut")
let { addPromoAction } = require("scripts/promo/promoActions.nut")

::g_user_utils <- {
  function getMyStateData()
  {
    let profileInfo = ::get_profile_info()
    let gameModeId = ::g_squad_manager.isSquadMember()
      ? ::g_squad_manager.getLeaderGameModeId()
      : ::game_mode_manager.getCurrentGameModeId()
    let event = ::events.getEvent(gameModeId)
    let prefParams = mapPreferencesParams.getParams(event)
    let myData = {
      name = profileInfo.name,
      clanTag = profileInfo.clanTag,
      pilotIcon = profileInfo.icon,
      rank = 0,
      country = profileInfo.country,
      crewAirs = null,
      selAirs = ::getSelAirsTable(),
      selSlots = getSelSlotsTable(),
      brokenAirs = null,
      cyberCafeId = ::get_cyber_cafe_id()
      unallowedEventsENames = ::events.getUnallowedEventEconomicNames(),
      crossplay = crossplayModule.isCrossPlayEnabled()
      bannedMissions = prefParams.bannedMissions
      dislikedMissions = prefParams.dislikedMissions
      craftsInfoByUnitsGroups = slotbarPresets.getCurCraftsInfo()
      platform = targetPlatform
      fakeName = ::get_option_in_mode(::USEROPT_REPLACE_MY_NICK_LOCAL, ::OPTIONS_MODE_GAMEPLAY).value != ""
    }

    let airs = getMyCrewUnitsState(profileInfo.country)
    myData.crewAirs = airs.crewAirs
    myData.brokenAirs = airs.brokenAirs
    if (airs.rank > myData.rank)
      myData.rank = airs.rank

    let checkPacks = ["pkg_main"]
    let missed = []
    foreach(pack in checkPacks)
      if (!::have_package(pack))
        missed.append(pack)
    if (missed.len())
      myData.missedPkg <- missed

    return myData
  }

  function checkAutoShowSteamEmailRegistration()
  {
    if (!::steam_is_running() || !haveTag("steamlogin") || !::has_feature("AllowSteamAccountLinking"))
      return

    if (::g_language.getLanguageName() != "Japanese")
    {
      if (::loadLocalByAccount("SteamEmailRegistrationShowed", false))
        return

      ::saveLocalByAccount("SteamEmailRegistrationShowed", true)
    }

    ::showUnlockWnd({
      name = ::loc("mainmenu/SteamEmailRegistration")
      desc = ::loc("mainmenu/SteamEmailRegistration/desc")
      popupImage = "ui/images/invite_big.jpg?P1"
      onOkFunc = function() { ::g_user_utils.launchSteamEmailRegistration() }
      okBtnText = "msgbox/btn_bind"
    })
  }

  function launchSteamEmailRegistration()
  {
    let token = ::get_steam_link_token()
    if (token == "")
      return ::dagor.debug("Steam Email Registration: empty token")

    openUrl(::loc("url/steam_bind_url",
        { token = token,
          langAbbreviation = ::g_language.getShortName()
        }), false, false, "profile_page")
  }

  function checkAutoShowPS4EmailRegistration()
  {
    if (!isPlatformSony || !haveTag("psnlogin"))
      return

    if (::loadLocalByAccount("PS4EmailRegistrationShowed", false))
      return

    ::saveLocalByAccount("PS4EmailRegistrationShowed", true)

    showUnlockWnd({
      name = ::loc("mainmenu/PS4EmailRegistration")
      desc = ::loc("mainmenu/PS4EmailRegistration/desc")
      popupImage = "ui/images/invite_big.jpg?P1"
      onOkFunc = function() { ::g_user_utils.launchPS4EmailRegistration() }
      okBtnText = "msgbox/btn_bind"
    })
  }

  function launchPS4EmailRegistration()
  {
    ::ps4_open_url_logged_in(::loc("url/ps4_bind_url"), ::loc("url/ps4_bind_redirect"))
  }

  function launchXboxEmailRegistration()
  {
    ::gui_modal_editbox_wnd({
      leftAlignedLabel = true
      title = ::loc("mainmenu/XboxOneEmailRegistration")
      label = ::loc("mainmenu/XboxOneEmailRegistration/desc")
      checkWarningFunc = ::g_string.validateEmail
      allowEmpty = false
      needOpenIMEonInit = false
      editBoxEnableFunc = @() ::g_user_utils.haveTag("livelogin")
      editBoxTextOnDisable = ::loc("mainmenu/alreadyBinded")
      editboxWarningTooltip = ::loc("tooltip/invalidEmail/possibly")
      okFunc = @(val) ::xbox_link_email(val, function(status) {
        ::g_popups.add("", ::colorize(
          status == ::YU2_OK? "activeTextColor" : "warningTextColor",
          ::loc("mainmenu/XboxOneEmailRegistration/result/" + status)
        ))
      })
    })
  }

  function haveTag(tag)
  {
    return ::get_player_tags().indexof(tag) != null
  }
}

let function onLaunchEmailRegistration(params) {
  let platformName = params?[0] ?? ""
  if (platformName == "")
    return

  let launchFunctionName = ::format("launch%sEmailRegistration", platformName)
  let launchFunction = ::g_user_utils?[launchFunctionName]
  if (launchFunction)
    launchFunction()
}

addPromoAction("email_registration", @(handler, params, obj) onLaunchEmailRegistration(params))
