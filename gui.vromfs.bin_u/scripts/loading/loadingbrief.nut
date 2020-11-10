local { clearBorderSymbolsMultiline } = require("std/string.nut")
local { getWeaponNameText } = require("scripts/weaponry/weaponryVisual.nut")
local changeStartMission = require("scripts/missions/changeStartMission.nut")
local { setDoubleTextToButton, setHelpTextOnLoading } = require("scripts/viewUtils/objectTextUpdate.nut")

const MIN_SLIDE_TIME = 2.0

::add_event_listener("FinishLoading", function(p) {
  ::stop_gui_sound("slide_loop")
  ::loading_stop_voice()
  ::loading_stop_music()
})

class ::gui_handlers.LoadingBrief extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/loadingCamp.blk"
  sceneNavBlkName = "gui/loadingNav.blk"

  gm = 0
  gt = 0

  function initScreen()
  {
    gm = ::get_game_mode()
    gt = ::get_game_type_by_mode(gm)

    ::set_presence_to_player("loading")
    setHelpTextOnLoading(scene.findObject("scene-help"))

    local blk = ::dgs_get_game_params()
    if ("loading" in blk && "numTips" in blk.loading)
    numTips = blk.loading.numTips

    local cutObj = guiScene["cutscene_update"]
    if (::checkObj(cutObj)) cutObj.setUserData(this)

    setDoubleTextToButton(scene, "btn_select", ::loc("hints/cutsc_skip"))

    local missionBlk = ::DataBlock()
    local country = ""
    if (::current_campaign_mission || ::is_mplayer_peer())
    {
      if (::is_mplayer_peer())
      {
        ::get_current_mission_desc(missionBlk)
        ::current_campaign_mission = missionBlk.getStr("name","")
      }
      else if (::get_game_type() & ::GT_DYNAMIC)
        missionBlk.setFrom(::mission_settings.mission)
      else if (::current_campaign_mission)
        missionBlk.setFrom(::get_mission_meta_info(::current_campaign_mission))

      if (gm == ::GM_TEST_FLIGHT)
        country = ::getCountryByAircraftName(::test_flight_aircraft.name)
      else
        country = ::getCountryByAircraftName(missionBlk.getStr("player_class", ""))
      dagor.debug("0 player_class = "+missionBlk.getStr("player_class", "") + "; country = " + country)
      if (country != "" && !(::get_game_type() & ::GT_VERSUS) && gm != ::GM_TRAINING)
        guiScene["briefing-flag"]["background-image"] = ::get_country_flag_img("bgflag_" + country)

      misObj_add = count_misObj_add(missionBlk)
    }

    partsList = []
    if (briefing)
    {
      local guiBlk = ::configs.GUI.get()
      local exclBlock = guiBlk?.slides_exclude?[get_country_flags_preset()]
      local excludeArray = exclBlock? (exclBlock % "name") : []

      local sceneInfo = ""
      if (::current_campaign_mission)
      {
        sceneInfo += ::loc(format("mb/%s/date", ::current_campaign_mission.tostring()), "")
        sceneInfo += (sceneInfo=="")? "" : "\n"
        sceneInfo += ::loc(format("mb/%s/place", ::current_campaign_mission.tostring()), "")
      }
      if (sceneInfo == "")
        sceneInfo = ::loc(briefing.getStr("place_loc", ""))
      setSceneInfo(sceneInfo)

      music = briefing.getStr("music","action_01")
      if ((::get_game_type() & ::GT_DYNAMIC) && country != "")
        music = country + "_main_theme"

      local prevSlide = ""

      for (local i = 0; i < briefing.blockCount(); i++)
      {
        local partBlock = briefing.getBlock(i);
        if (partBlock.getBlockName() == "part")
        {
          local part =
          {
            subtitles = ::loc(partBlock.getStr("event", ""))
            slides = []
          }
          part.event <- partBlock.getStr("event", "")
          for (local idx = part.event.indexof("/"); idx; )
            if (idx != null)
            {
              part.event = part.event.slice(0, idx)+"_"+part.event.slice(idx+1)
              idx = part.event.indexof("/")
            }
          part.voiceLen <- ::loading_get_voice_len(part.event) //-1 if there's no sound
          dagor.debug("voice "+part.event+" len "+part.voiceLen.tostring())

          local totalSlidesTime = 0.0
          local freeTimeSlides = []
          foreach(slideBlock in partBlock % "slide")
          {
            local image = slideBlock.getStr("picture", "")
            if (image != "")
            {
              if (::find_in_array(excludeArray, image, -1) >= 0)
              {
                dagor.debug("EXCLUDE by: " + ::get_country_flags_preset() + "; slide " + image)
                continue
              }
            }
            local slide = {
              time = (slideBlock?.minTime ?? 0).tofloat()
              image = image
              map = slideBlock.getBool("map", false)
            }
            part.slides.append(slide)

            if (slide.time <= 0)
              freeTimeSlides.append(slide)
            if (slide.time < MIN_SLIDE_TIME)
              slide.time = MIN_SLIDE_TIME
            totalSlidesTime += slide.time

            if (slide.image != "")
              prevSlide = slide.image
          }

          if (!part.slides.len())
          {
            local partTime = part.voiceLen
            if (partTime <= 0)
              partTime = (partBlock?.minTime ?? 0).tofloat()
            part.slides.append({
              time = ::max(partTime, MIN_SLIDE_TIME)
              image = prevSlide
              map = false
            })
          }
          else if (part.voiceLen > totalSlidesTime)
          {
            if (freeTimeSlides.len())
            {
              local slideTimeDiff = (part.voiceLen - totalSlidesTime) / freeTimeSlides.len()
              foreach(slide in freeTimeSlides)
                slide.time += slideTimeDiff
            }
            else if (totalSlidesTime)
            {
              local slideTimeMul = part.voiceLen / totalSlidesTime
              foreach(slide in part.slides)
                slide.time *= slideTimeMul
            }
          }

          partsList.append(part)
        }
      }
    }
    if (partsList.len() == 0)
      finished = true

    if (gchat_is_enabled() && ::has_feature("Chat"))
      switchMenuChatObjIfVisible(getChatDiv(scene))

    if (gt & ::GT_VERSUS)
    {
      local missionHelpPath = ::g_mission_type.getHelpPathForCurrentMission()
      local haveHelp = ::has_feature("ControlsHelp") && missionHelpPath != null

      local helpBtnObj = showSceneBtn("btn_help", haveHelp)
      if (helpBtnObj && !::show_console_buttons)
        helpBtnObj.setValue(::loc("flightmenu/btnControlsHelp") + ::loc("ui/parentheses/space", { text = "F1" }))

      if (haveHelp)
      {
        local parts = ::split(missionHelpPath, "/.")
        local helpId = parts.len() >= 2 ? parts[parts.len() - 2] : ""
        local cfgPath = "seen/help_mission_type/" + helpId
        local isSeen = ::loadLocalByAccount(cfgPath, 0)
        if (!isSeen)
        {
          onHelp()
          ::saveLocalByAccount(cfgPath, 1)
        }
      }
    }
  }

  function count_misObj_add(blk)
  {
    local res = []

    local m_aircraft = blk.getStr("player_class", "")
    local m_weapon = blk.getStr("player_weapons", "")

    if (gm == ::GM_TEST_FLIGHT)
    {
      m_aircraft = ::test_flight_aircraft.name
      m_weapon = ::get_gui_option(::USEROPT_WEAPONS)
    }
    if ((m_aircraft != "") && !(gt & ::GT_VERSUS))
      res.append(::loc("options/aircraft") + ::loc("ui/colon") +
                    " " + ::getUnitName(m_aircraft) + "; " +
                    getWeaponNameText(m_aircraft, null, m_weapon, ", "))

    local m_condition = ""
    if (::current_campaign_mission)
      m_condition = ::loc("missions/"+::current_campaign_mission+"/condition", "")

    if (m_condition == "")
    {
      if (!(gt & ::GT_VERSUS))
      {
        local m_location = blk.getStr("locationName", ::map_to_location(blk.getStr("level", "")))
        if (m_location != "")
          m_condition += ::loc("location/" + m_location)
        local m_time = blk.getStr("time", blk.getStr("environment", ""))
        if (m_time != "")
          m_condition += (m_condition != "" ? "; " : "") + ::get_mission_time_text(m_time)
        local m_weather = blk.getStr("weather", "")
        if (m_weather != "")
          m_condition += (m_condition != "" ? "; " : "") + ::loc("options/weather" + m_weather)
      }
    }
    if (m_condition != "")
      res.append(::loc("sm_conditions") + ::loc("ui/colon") + " " + m_condition)
    return ::g_string.implode(res, "\n")
  }

  function onUpdate(obj, dt)
  {
    if (!finished)
      slidesUpdate(dt)

    if (nextSlideImg && isSlideReady())
    {
      showSlide()
      checkNewSubtitles()
    }

    if (waitForMap)
      showMap()

    if (applyReady != ::loading_is_finished())
    {
      applyReady = ::loading_is_finished()
      local showStart = !::is_multiplayer() && gm != ::GM_TRAINING && !changeStartMission
      if ((applyReady && !showStart) || finished)
        finishLoading()
      else
      {
        showSceneBtn("btn_select", applyReady && showStart)
        showSceneBtn("loadanim", !applyReady)
      }
    }

    if (finished && (!waitForMap))
    {  //tipsUpdate
      _tipTime -= dt
      if (tipShow && (_tipTime < 0))
      {
        setSceneInfo("")
        tipShow = false
      }
      if (_tipTime < -1)
      {
        _tipTime = tipShowTime
//        if (!::loading_is_finished())
        {
          tipShow = true
          setSceneInfo(::g_tips.getTip())
        }
      }
    }
  }

  function checkNewSubtitles()
  {
    if (nextSubtitles)
    {
      setSubtitles(nextSubtitles)
      nextSubtitles = null
    }
  }

  function slidesUpdate(dt)
  {
    slideTime -= dt
    if (slideTime <= 0)
      checkNextSlide()
  }

  function checkNextSlide()
  {
    local isLastSlideInPart = slideIdx >= partsList[partIdx].slides.len() - 1
    if (isLastSlideInPart && ::loading_is_voice_playing())
      return

    if (!slidesStarted)
    {
      slidesStarted = true
      onSlidesStart()
    }

    if (!isLastSlideInPart)
      slideIdx++
    else
    {
      partIdx++
      setSubtitles("")
      if (partIdx >= partsList.len() || !partsList[partIdx].slides.len())
      {
        setFinished()
        if (::loading_is_finished())
          finishLoading()
        return
      }
      else
      {
        slideIdx = 0
        nextSubtitles = partsList[partIdx].subtitles
        ::loading_stop_voice_but_named_events()
        ::loading_play_voice(partsList[partIdx].event, true)
        dagor.debug("loading_play_voice "+partsList[partIdx].event.tostring())
      }
    }

    //next Slide show
    local curSlide = partsList[partIdx].slides[slideIdx]

    slideTime = curSlide.time

    if (curSlide.map)
      showMap()
    else
      setSlide(curSlide.image)
  }

  function setFinished()
  {
    finished = true
    showMap()
  }

  function onSlidesStart()
  {
    setSceneTitle(getCurMpTitle())
    if (partsList.len() > 0)
    {
      setSubtitles(partsList[0].subtitles)
      ::loading_play_music(music)
      ::loading_play_voice(partsList[0].event, true)
      dagor.debug("loading_play_voice "+partsList[0].event.tostring())
    }
    start_gui_sound("slide_loop")
  }

  function setSlide(imgName)
  {
    nextSlideImg = (imgName != "")? imgName : null
    hideSlide()
  }

  function hideSlide()
  {
    guiScene["slide-place"].animShow = "hide"
    if (!hideSoundPlayed)
    {
      guiScene.playSound("slide_in")
      hideSoundPlayed = true
    }
  }

  function showSlide()
  {
    showProjectorGlow(true)
    showProjectorSmallGlow(false)
    local place = guiScene["slide-place"]
    place.animShow = "show"
    guiScene.playSound("slide_out")
    hideSoundPlayed = false
    if (nextSlideImg)
    {
      guiScene["slide-img"]["background-image"] = format("ui/slides/%s.jpg?P1", nextSlideImg)
      place.rotation = (2.0*::math.frnd() - 1.0).tostring()
      place.padding = format("%fsh, %fsh, 0, 0", 0.1*(::math.frnd() - 0.5), 0.05*(::math.frnd() - 0.5))
      nextSlideImg = null
    }
  }

  function showProjectorGlow(show)
  {
    if (guiScene["briefingglow"])
      guiScene["briefingglow"].show(show)
  }
  function showProjectorSmallGlow(show)
  {
    if (guiScene["briefingsmallglow"])
      guiScene["briefingsmallglow"].show(show)
  }

  function isSlideReady()
  {
    return (guiScene["slide-place"]["_pos-timer"] == "0")
  }

  function setSceneInfo(text)
  {
    safeSetValue("scene-info", text)
  }

  function setSubtitles(text)
  {
    safeSetValue("scene-subtitles", text)
  }

  function showMap()
  {
    if (isSlideReady())
    {
      showProjectorGlow(false)
      showProjectorSmallGlow(true)
      checkNewSubtitles()
      waitForMap = false
      if (briefing)
      {
        local misObj = ""
        if (::current_campaign_mission)
          misObj = ::loc(format("mb/%s/objective", ::current_campaign_mission.tostring()), "")
        if ((gt & ::GT_VERSUS) && ::current_campaign_mission)
          misObj = ::loc_current_mission_desc()
        if (misObj == "" && ::current_campaign_mission)
          misObj = ::loc(format("missions/%s/objective", ::current_campaign_mission.tostring()), "")
        if (misObj == "")
          misObj = ::loc(briefing.getStr("objective_loc", ""))
        if (misObj_add != "")
          misObj += (misObj.len() ? "\n\n" : "") + misObj_add

        misObj = ::colorize("userlogColoredText", ::loc_current_mission_name(false)) +
          "\n\n" + clearBorderSymbolsMultiline(misObj)
        setMissionObjective(misObj)
      }

      if (guiScene["map-background"])
        guiScene["map-background"].show(true)
      if (guiScene["darkscreen"])
        guiScene["darkscreen"].animShow = "show"
      setSceneInfo("")

      local obj = guiScene?["tactical-map"]
      if (obj)
      {
        if (obj?.animShow != "show")
          guiScene.playSound("show_map")
        obj.animShow = "show"
        obj.show(true)
      }
    }
    else
    {
      hideSlide()
      waitForMap = true
    }
  }

  function setMissionObjective(text)
  {
    safeSetValue("mission-objectives", text)
  }

  function safeSetValue(objName, value)
  {
    local show = (value != null)&&(value != "")
    local obj = guiScene[objName]
    if (obj)
    {
      if (show)
        obj.setValue(value)
      obj.animShow = (show) ? "show" : "hide"
    }
  }

  function onHelp(obj = null)
  {
    ::gui_modal_help(false, HELP_CONTENT_SET.LOADING)
  }

  function onApply(obj)
  {
    ::loading_stop_voice()
    ::loading_stop_music()
    ::loading_press_apply()
  }

  function finishLoading()
  {
    ::loading_stop_voice()
    ::loading_stop_music()
    ::briefing_finish()
  }

  function onTestBack(obj)
  {
    goForward(::gui_start_mainmenu)
  }

  testTimer = 0

  nextSlideImg = null
  nextSubtitles = null
  waitForMap = false
  briefing = null
  partsList = null
  misObj_add = ""

  slidesStarted = false
  finished = false
  slideTime = 1.0  //time before next slide
  partIdx = 0
  slideIdx = -1
  music = ""

  numTips = 24
  tipShowTime = 10
  _tipTime = 1
  tipShow = false
  tipId = -1

  hideSoundPlayed = false
  applyReady = true
}