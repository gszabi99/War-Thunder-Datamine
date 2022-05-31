/* API:
  static create(nest, mission = null)
    creates description handler into <nest>, and init with selected <mission>

  setMission(mission, previewBlk = null)
    set <mission> and mapPreview (<previewBlk>)
    if previewBlk == null - previw will be loaded automatically


  //!!FIX ME:
  applyDescConfig(config) - direct used atm, but better to exchange them on events
*/

let { getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { checkJoystickThustmasterHotas } = require("%scripts/controls/hotas.nut")
let { getMissionRewardsMarkup, getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { getTutorialFirstCompletRewardData } = require("%scripts/tutorials/tutorialsData.nut")

::gui_handlers.MissionDescription <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/missionDescr.blk"

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
    let params = {
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
    let chaptersBlk = ::DataBlock()
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
    let previewBlk = ::getTblValue("previewBlk", config)
    ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), previewBlk)
    guiScene.applyPendingChanges(false) //need to refresh object sizes after map appear or disappear

    guiScene.setUpdatesEnabled(false, false)

    foreach(name in descItems)
      getObj("descr-" + name).setValue((name in config)? config[name] : "")

    getObj("descr-flag")["background-image"] = ("flag" in config && gm != ::GM_BENCHMARK)? config.flag : ""
    getObj("descr-chapterImg")["background-image"] = ("chapterImg" in config)? config.chapterImg : ""

    let rewardsObj = getObj("descr-rewards")
    let isShow = (config?.rewards.len() ?? 0) > 0
    rewardsObj.show(isShow)
    if (isShow)
      guiScene.replaceContentFromText(rewardsObj, config.rewards, config.rewards.len(), this)

    let countriesObj = getObj("descr-countries")
    if ("countries" in config)
    {
      guiScene.replaceContentFromText(countriesObj, config.countries, config.countries.len(), this)
      countriesObj.show(true)
    } else
      countriesObj.show(false)

    guiScene.setUpdatesEnabled(true, true)

    let nameObj = getObj("descr_scroll_top_point")
    if (::checkObj(nameObj))
      nameObj.scrollToView()
  }

  function getHeaderDescConfig(mission)
  {
    let config = {}
    config.name <- ::loc((mission.isCampaign? "campaigns/" : "chapters/")+mission.id)
    config.maintext <- ::loc((mission.isCampaign? "campaigns/" : "chapters/")+mission.id+"/desc", "")
    if (mission.id in chapterImgList)
      config.chapterImg <- "ui/chapters/"+mission.id
    return config
  }

  function getUrlMissionDescConfig(mission)
  {
    let urlMission = ::getTblValue("urlMission", mission)
    if (!urlMission)
      return {}

    let config = getBlkMissionDescConfig(mission, urlMission.fullMissionBlk)
    config.name <- urlMission.name
    config.maintext <- urlMission.hasErrorByLoading ? ::colorize("badTextColor", urlMission.url) : urlMission.url
    return config
  }

  function getBlkMissionDescConfig(mission, previewBlk = null)
  {
    let config = {}
    let blk = ::g_mislist_type.isUrlMission(curMission)
                ? curMission.urlMission.getMetaInfo()
                : ::getTblValue("blk", mission)
    if (!blk)
      return config

    let gt = ::get_game_type_by_mode(gm)
    if (previewBlk)
      config.previewBlk <- previewBlk
    else
    {
      let m = DataBlock()
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

      if (checkJoystickThustmasterHotas(false) && gm == ::GM_TRAINING)
      {
        if (::is_mission_for_unittype(blk, ::ES_UNIT_TYPE_TANK))
          config.hotas4_tutorial_usage_restriction <- ::loc("tutorials/hotas_restriction/tank")
        else if (mission.chapter == "tutorial_adv")
          config.hotas4_tutorial_usage_restriction <- ::loc("tutorials/hotas_restriction")
      }
    }
    if (gm == ::GM_SINGLE_MISSION)
    {
      let missionAvailableForCoop = blk.getBool("gt_cooperative", false)
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

    let aircraft = blk.getStr("player_class", "")
    if ((aircraft != "") && !(gt & ::GT_VERSUS)
        && (gm != ::GM_EVENT) && (gm != ::GM_TOURNAMENT) && (gm != ::GM_DYNAMIC) && (gm != ::GM_BUILDER) && (gm != ::GM_BENCHMARK))
    {
      config.aircraftItem <- ::loc("options/aircraft") + ::loc("ui/colon")
      config.aircraft <- ::getUnitName(aircraft) + "; " +
                 getWeaponNameText(aircraft, null, blk.getStr("player_weapons", ""), ", ")

      let country = ::getShopCountry(aircraft)
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
      let option = ::get_option(::USEROPT_TIME_LIMIT)
      let timeLimitText = option.getTitle() + ::loc("ui/colon") + option.getValueLocText(blk.timeLimit)
      config.maintext += (config.maintext.len() ? "\n\n" : "") + timeLimitText
    }

    if ((blk?["locDescTeamA"].len() ?? 0) > 0)
      config.objective <- getMissionLocName(blk, "locDescTeamA")
    else if ((blk?.locDesc.len() ?? 0) > 0)
      config.objective <- getMissionLocName(blk, "locDesc")
    if (blk.getStr("recommendedPlayers","") != "")
      config.maintext += ::format(::loc("players_recommended"), blk.getStr("recommendedPlayers","1-4")) + "\n"

    let rBlk = ::get_pve_awards_blk()
    if (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION || gm == ::GM_TRAINING)
    {
      let status = max(mission.singleProgress, mission.onlineProgress)
      config.status <- status
      let dataBlk = rBlk?[::get_game_mode_name(gm)]
      if (dataBlk)
      {
        let rewardsConfig = [{
          highlighted = ::DIFFICULTY_ARCADE > status
          isComplete = ::DIFFICULTY_ARCADE <= status
          isBaseReward = true
        }]

        if (gm != ::GM_TRAINING)
          rewardsConfig.append({
            locId = "difficulty1"
            diff = ::DIFFICULTY_REALISTIC
            highlighted = ::DIFFICULTY_REALISTIC > status
            isComplete = ::DIFFICULTY_REALISTIC <= status
            isAdditionalReward = true
          },
          {
            locId = "difficulty2"
            diff = ::DIFFICULTY_HARDCORE
            highlighted = ::DIFFICULTY_HARDCORE > status
            isComplete = ::DIFFICULTY_HARDCORE <= status
            isAdditionalReward = true
          })
        else {
          let firstCompletRewardData = getTutorialFirstCompletRewardData(dataBlk?[mission.id], {
            showFullReward = true
            isMissionComplete = ::DIFFICULTY_ARCADE <= status
          })
          if (firstCompletRewardData.hasReward)
            rewardsConfig.append(firstCompletRewardData)
        }
        config.rewards <- getMissionRewardsMarkup(dataBlk, mission.id, rewardsConfig)
      }
    } else
    if (gm == ::GM_DYNAMIC && rBlk?.dynamic)
    {
      let dataBlk = rBlk.dynamic
      let rewMoney = ::Cost()
      let xpId = "xpEarnedWinDiff0"
      let wpId = "wpEarnedWinDiff0"
      let muls = ::get_player_multipliers()

      rewMoney.rp = (dataBlk?[xpId] != null)
                     ? dataBlk[xpId] * muls.xpMultiplier
                     : 0

      rewMoney.wp = (dataBlk?[wpId] != null)
                    ? dataBlk[wpId] * muls.wpMultiplier
                    : 0

      let mul = ("presetName" in mission)
                  ? dataBlk[mission.presetName]
                  : 0.0
      if (mul)
        config.baseReward <- buildRewardText(::loc("baseReward"), rewMoney.multiply(mul), true, true)

      let reqAir = ("player_class" in mission.blk? mission.blk.player_class : "")
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
        let unitNameLoc = ::colorize("activeTextColor", ::getUnitName(curMission.mustHaveUnit))
        config.requirements <- ::loc("conditions/char_unit_exist/single", { value = unitNameLoc })
      }
      else
      {
        let unlockName = mission.blk.chapter + "/" + mission.blk.name
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