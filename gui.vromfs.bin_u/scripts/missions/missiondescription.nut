/* API:
  static create(nest, mission = null)
    creates description handler into <nest>, and init with selected <mission>

  setMission(mission, previewBlk = null)
    set <mission> and mapPreview (<previewBlk>)
    if previewBlk == null - previw will be loaded automatically


  //!!FIX ME:
  applyDescConfig(config) - direct used atm, but better to exchange them on events
*/

local { getWeaponNameText } = require("scripts/weaponry/weaponryVisual.nut")
class ::gui_handlers.MissionDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/missionDescr.blk"

  curMission = null
  mapPreviewBlk = null //when not set, detected by mission
  gm = ::GM_SINGLE_MISSION

  chapterImgList = null
  descItems = ["name", "date", "coop", "aircraftItem", "aircraft", "maintext",
               "objectiveItem", "objective", "conditionItem", "condition", "wpAward",
               "location", "locationItem", "time", "timeItem", "weather", "weatherItem",
               "playable", "playableItem", "rank", "rankItem",
               "difficulty", "difficultyItem", "players", "playersItem",
               "fuelAndAmmo", "fuelAndAmmoItem", "repeat", "repeatItem",
               "roundsItem", "rounds", "aircraftsListItem", "aircraftsList",
               "requirementsItem", "requirements", "baseReward",
               "hotas4_tutorial_usage_restriction"]

  static function create(nest, mission = null)
  {
    local params = {
      scene = nest
      curMission = mission
    }
    return ::handlersManager.loadHandler(::gui_handlers.MissionDescription, params)
  }

  function initScreen()
  {
    gm = ::get_game_mode()
    initChaptersImages()
    update()
  }

  function initChaptersImages() //!!FIX ME: better to init this once per login
  {
    chapterImgList = {}
    local chaptersBlk = ::DataBlock()
    chaptersBlk.load("config/chapters.blk")
    foreach(cBlk in chaptersBlk % "images")
      if (::u.isDataBlock(cBlk))
        for (local i = 0; i < cBlk.paramCount(); i++)
          chapterImgList[cBlk.getParamName(i)] <- true
  }

  function setMission(mission, previewBlk = null)
  {
    curMission = mission
    mapPreviewBlk = previewBlk
    update()
  }

  function update()
  {
    local config = {}
    if (curMission)
    {
      if (::g_mislist_type.isUrlMission(curMission))
        config = getUrlMissionDescConfig(curMission)
      else if (curMission.isHeader)
        config = getHeaderDescConfig(curMission)
      else if ("blk" in curMission)
        config = getBlkMissionDescConfig(curMission, mapPreviewBlk)
    }

    applyDescConfig(config)
    updateButtons()
  }

  function updateButtons()
  {
    showSceneBtn("btn_url_mission_refresh", ::g_mislist_type.isUrlMission(curMission))
  }

  function applyDescConfig(config)
  {
    local previewBlk = ::getTblValue("previewBlk", config)
    ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), previewBlk)
    guiScene.applyPendingChanges(false) //need to refresh object sizes after map appear or disappear

    guiScene.setUpdatesEnabled(false, false)

    foreach(name in descItems)
      getObj("descr-" + name).setValue((name in config)? config[name] : "")

    getObj("descr-flag")["background-image"] = ("flag" in config && gm != ::GM_BENCHMARK)? config.flag : ""
    getObj("descr-chapterImg")["background-image"] = ("chapterImg" in config)? config.chapterImg : ""

    local status = ("status" in config)? config.status : -1
    for(local i=0; i<3; i++)
    {
      local text = (("reward"+i) in config)? config["reward"+i] : ""
      getObj("descr-reward"+i).setValue(text)
      getObj("descr-status"+i).show(text!="")
      getObj("descr-completed"+i).show(status >= i)
    }

    local countriesObj = getObj("descr-countries")
    if ("countries" in config)
    {
      guiScene.replaceContentFromText(countriesObj, config.countries, config.countries.len(), this)
      countriesObj.show(true)
    } else
      countriesObj.show(false)

    guiScene.setUpdatesEnabled(true, true)

    local nameObj = getObj("descr_scroll_top_point")
    if (::checkObj(nameObj))
      nameObj.scrollToView()
  }

  function getHeaderDescConfig(mission)
  {
    local config = {}
    config.name <- ::loc((mission.isCampaign? "campaigns/" : "chapters/")+mission.id)
    config.maintext <- ::loc((mission.isCampaign? "campaigns/" : "chapters/")+mission.id+"/desc", "")
    if (mission.id in chapterImgList)
      config.chapterImg <- "ui/chapters/"+mission.id
    return config
  }

  function getUrlMissionDescConfig(mission)
  {
    local urlMission = ::getTblValue("urlMission", mission)
    if (!urlMission)
      return {}

    local config = getBlkMissionDescConfig(mission, urlMission.fullMissionBlk)
    config.name <- urlMission.name
    config.maintext <- urlMission.hasErrorByLoading ? ::colorize("badTextColor", urlMission.url) : urlMission.url
    return config
  }

  function getBlkMissionDescConfig(mission, previewBlk = null)
  {
    local config = {}
    local blk = ::g_mislist_type.isUrlMission(curMission)
                ? curMission.urlMission.getMetaInfo()
                : ::getTblValue("blk", mission)
    if (!blk)
      return config

    local gt = ::get_game_type_by_mode(gm)
    if (previewBlk)
      config.previewBlk <- previewBlk
    else
    {
      local m = DataBlock()
      m.load(blk.getStr("mis_file",""))
      config.previewBlk <- m
    }

    config.name <- mission.misListType.getMissionNameText(mission)

    if (gm == ::GM_CAMPAIGN)
        config.date <- ::loc("mb/"+mission.id+"/date")
    else if (gm == ::GM_SINGLE_MISSION || gm == ::GM_TRAINING)
    {
      config.date <- ::loc("missions/"+mission.id+"/date")
      config.objectiveItem <- ::loc("sm_objective") + ::loc("ui/colon")
      config.objective <- ::loc("missions/"+mission.id+"/objective")

      if (::check_joystick_thustmaster_hotas(false) && gm == ::GM_TRAINING)
      {
        if (::is_mission_for_unittype(blk, ::ES_UNIT_TYPE_TANK))
          config.hotas4_tutorial_usage_restriction <- ::loc("tutorials/hotas_restriction/tank")
        else if (mission.chapter == "tutorial_adv")
          config.hotas4_tutorial_usage_restriction <- ::loc("tutorials/hotas_restriction")
      }
    }
    if (gm == ::GM_SINGLE_MISSION)
    {
      local missionAvailableForCoop = blk.getBool("gt_cooperative", false)
        && ::can_play_gamemode_by_squad(gm)
        && !::is_user_mission(blk)
      config.coop <- missionAvailableForCoop? ::loc("single_mission/available_for_coop") : ""
    }
    if (gm == ::GM_CAMPAIGN || gm == ::GM_DYNAMIC)
    {
      config.objectiveItem <- ::loc("sm_objective") + ::loc("ui/colon")
      config.objective <- ::loc("mb/"+mission.id+"/objective")
    }

    config.condition <- ::loc("missions/"+mission.id+"/condition", "")
    if ((config.condition == "") && (gm != ::GM_TEAMBATTLE) && (gm != ::GM_DOMINATION) && (gm != ::GM_SKIRMISH))
    {
      local sm_location = blk.getStr("locationName", ::map_to_location(blk.getStr("level", "")))
      if (sm_location != "")
        sm_location = ::loc("location/" + sm_location)

      local sm_time = blk.getStr("time", blk.getStr("environment", ""))
      if (sm_time != "")
        sm_time = ::get_mission_time_text(sm_time)

      local sm_weather = blk.getStr("weather", "")
      if (sm_weather != "")
        sm_weather = ::loc("options/weather" + sm_weather)

      config.condition += sm_location
      config.condition += (config.condition != "" ? "; " : "") + sm_time
      config.condition += (config.condition != "" ? "; " : "") + sm_weather

      if (gm == ::GM_DYNAMIC)
      {
        config.date <- config.condition
        config.condition = ""
      }
    }
    if (config.condition != "")
      config.conditionItem <- ::loc("sm_conditions") + ::loc("ui/colon")

    local aircraft = blk.getStr("player_class", "")
    if ((aircraft != "") && !(gt & ::GT_VERSUS)
        && (gm != ::GM_EVENT) && (gm != ::GM_TOURNAMENT) && (gm != ::GM_DYNAMIC) && (gm != ::GM_BUILDER) && (gm != ::GM_BENCHMARK))
    {
      config.aircraftItem <- ::loc("options/aircraft") + ::loc("ui/colon")
      config.aircraft <- ::getUnitName(aircraft) + "; " +
                 getWeaponNameText(aircraft, null, blk.getStr("player_weapons", ""), ", ")

      local country = ::getShopCountry(aircraft)
      dagor.debug("aircraft = "+aircraft+" country = "+country)
      config.flag <- ::get_country_icon(country, true)
    }


    config.maintext <- ::loc("missions/"+mission.id+"/desc", "")
    if (gm == ::GM_SKIRMISH && config.maintext != "" && !("objective" in config))
    {
      config.objective <- "\n"+config.maintext
      config.maintext = ""
    }
    else if (gm == ::GM_DOMINATION && blk?.timeLimit)
    {
      local option = ::get_option(::USEROPT_TIME_LIMIT)
      local timeLimitText = option.getTitle() + ::loc("ui/colon") + option.getValueLocText(blk.timeLimit)
      config.maintext += (config.maintext.len() ? "\n\n" : "") + timeLimitText
    }

    if ((blk?["locDescTeamA"].len() ?? 0) > 0)
      config.objective <- ::get_locId_name(blk, "locDescTeamA")
    else if ((blk?.locDesc.len() ?? 0) > 0)
      config.objective <- ::get_locId_name(blk, "locDesc")
    if (blk.getStr("recommendedPlayers","") != "")
      config.maintext += ::format(::loc("players_recommended"), blk.getStr("recommendedPlayers","1-4")) + "\n"

    local rBlk = ::get_pve_awards_blk()
    if (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION || gm == ::GM_TRAINING)
    {
      config.status <- max(mission.singleProgress, mission.onlineProgress)
      local dataBlk = rBlk?[::get_game_mode_name(gm)]
      if (dataBlk)
      {
        //local misDataBlk = dataBlk[mission.id]
        local diffList = (gm==::GM_TRAINING)? ["reward"] : ["reward", "difficulty1", "difficulty2"]
        //local muls = ::get_player_multipliers()
        foreach(diff, langId in diffList)
          config["reward"+diff] <- ::getRewardTextByBlk(dataBlk, mission.id, diff, langId, diff > config.status, true, diff > 0)
      }
    } else
    if (gm == ::GM_DYNAMIC && rBlk?.dynamic)
    {
      local dataBlk = rBlk.dynamic
      local rewMoney = ::Cost()
      local xpId = "xpEarnedWinDiff0"
      local wpId = "wpEarnedWinDiff0"
      local muls = ::get_player_multipliers()

      rewMoney.rp = (dataBlk?[xpId] != null)
                     ? dataBlk[xpId] * muls.xpMultiplier
                     : 0

      rewMoney.wp = (dataBlk?[wpId] != null)
                    ? dataBlk[wpId] * muls.wpMultiplier
                    : 0

      local mul = ("presetName" in mission)
                  ? dataBlk[mission.presetName]
                  : 0.0
      if (mul)
        config.baseReward <- buildRewardText(::loc("baseReward"), rewMoney.multiply(mul), true, true)

      local reqAir = ("player_class" in mission.blk? mission.blk.player_class : "")
      if(reqAir != "")
      {
        config.aircraftItem <- ::loc("options/aircraft") + ::loc("ui/colon")
        config.aircraft <- ::getUnitName(reqAir)
      }
    }

    if ((gm == ::GM_SINGLE_MISSION) && (mission.progress >= 4))
    {
      config.requirementsItem <- ::loc("unlocks/requirements") + ::loc("ui/colon")
      if ("mustHaveUnit" in curMission)
      {
        local unitNameLoc = ::colorize("activeTextColor", ::getUnitName(curMission.mustHaveUnit))
        config.requirements <- ::loc("conditions/char_unit_exist/single", { value = unitNameLoc })
      }
      else
      {
        local unlockName = mission.blk.chapter + "/" + mission.blk.name
        config.requirements <- ::get_unlock_description(unlockName, 1, true)
      }
    }

    return config
  }

  function onUrlMissionRefresh(obj)
  {
    if (::g_mislist_type.isUrlMission(curMission))
      ::g_url_missions.loadBlk(curMission)
  }

  function onEventUrlMissionLoaded(p)
  {
    if (::g_mislist_type.isUrlMission(curMission))
      update()
  }
}