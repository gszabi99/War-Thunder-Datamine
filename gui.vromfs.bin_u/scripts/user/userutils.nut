local crossplayModule = require("scripts/social/crossplay.nut")
local mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")

local needShowRateWnd = false //need this, because debriefing data destroys after debriefing modal is closed

::g_user_utils <- {
  function setNeedShowRate(val)
  {
    needShowRateWnd = val
  }

  function checkShowRateWnd()
  {
    //can be on any platform in future,
    //no need to specify platform in func name
    //but now only for xbox have such ability.
    if (!::is_platform_xboxone)
      return

    //show only if player win last mp battle
    if (!needShowRateWnd)
      return

    local path = "seen/rateWnd"
    if (::load_local_account_settings(path, false))
      return

    if (::xbox_show_rate_and_review()) //if success - save show status
      ::save_local_account_settings(path, true)

    // in case of error, show in next launch.
    needShowRateWnd = false
  }

  function getMyStateData()
  {
    local profileInfo = ::get_profile_info()
    local gameModeId = ::g_squad_manager.isSquadMember()
      ? ::g_squad_manager.getLeaderGameModeId()
      : ::game_mode_manager.getCurrentGameModeId()
    local event = ::events.getEvent(gameModeId)
    local prefParams = mapPreferencesParams.getParams(event)
    local myData = {
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
    }

    local airs = getMyCrewAirsState(profileInfo)
    myData.crewAirs = airs.crewAirs
    myData.brokenAirs = airs.brokenAirs
    if (airs.rank > myData.rank)
      myData.rank = airs.rank

    local checkPacks = ["pkg_main"]
    local missed = []
    foreach(pack in checkPacks)
      if (!::have_package(pack))
        missed.append(pack)
    if (missed.len())
      myData.missedPkg <- missed

    return myData
  }

  function getMyCrewAirsState(profileInfo = null)
  {
    if (profileInfo == null)
      profileInfo = ::get_profile_info()

    local res = {
      crewAirs = {}
      brokenAirs = []
      rank = 0
    }

    foreach(c in ::g_crews_list.get())
    {
      if (!("crews" in c))
        continue

      res.crewAirs[c.country] <- []
      foreach(crew in c.crews)
        if (("aircraft" in crew) && crew.aircraft!="")
        {
          local air = getAircraftByName(crew.aircraft)
          if (air)
          {
            res.crewAirs[c.country].append(crew.aircraft)
            if (c.country == profileInfo.country && res.rank < air.rank)
              res.rank = air.rank
            if (::wp_get_repair_cost(crew.aircraft))
              res.brokenAirs.append(crew.aircraft)
          }
        }
    }

    return res
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
    local token = ::get_steam_link_token()
    if (token == "")
      return ::dagor.debug("Steam Email Registration: empty token")

    ::open_url(::loc("url/steam_bind_url",
        { token = token,
          langAbbreviation = ::g_language.getShortName()
        }), false, false, "profile_page")
  }

  function checkAutoShowPS4EmailRegistration()
  {
    if (!::is_platform_ps4 || !haveTag("psnlogin"))
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
      title = ::loc("mainmenu/XboxOneEmailRegistration")
      editboxHeaderText = ::loc("mainmenu/XboxOneEmailRegistration/desc")
      checkButtonFunc = ::g_string.validateEmail
      allowEmpty = false
      needOpenIMEonInit = false
      editBoxEnableFunc = @() ::g_user_utils.haveTag("livelogin")
      editBoxTextOnDisable = ::loc("mainmenu/alreadyBinded")
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