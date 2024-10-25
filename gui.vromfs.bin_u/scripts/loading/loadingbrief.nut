from "%scripts/dagui_natives.nut" import stop_gui_sound, start_gui_sound, set_presence_to_player, gchat_is_enabled, map_to_location
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

let { g_mission_type } = require("%scripts/missions/missionType.nut")
let { get_game_params_blk } = require("blkGetters")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { find_in_array } = require("%sqStdLibs/helpers/u.nut")
let { format, split_by_chars } = require("string")
let { frnd } = require("dagor.random")
let DataBlock = require("DataBlock")
let { get_gui_option } = require("guiOptions")
let { is_mplayer_peer } = require("multiplayer")
let { loading_is_finished, loading_press_apply, briefing_finish, loading_play_voice,
  loading_stop_voice, loading_stop_voice_but_named_events, loading_get_voice_len,
  loading_is_voice_playing, loading_play_music, loading_stop_music
} = require("loading")
let { get_game_mode, get_game_type, get_game_type_by_mode } = require("mission")
let { clearBorderSymbolsMultiline } = require("%sqstd/string.nut")
let { getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let changeStartMission = require("%scripts/missions/changeStartMission.nut")
let { setDoubleTextToButton, setHelpTextOnLoading } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { getTip } = require("%scripts/loading/loadingTips.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUrlOrFileMissionMetaInfo, locCurrentMissionName, getMissionTimeText, getWeatherLocName
} = require("%scripts/missions/missionsUtils.nut")
let { get_current_mission_desc } = require("guiMission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_WEAPONS } = require("%scripts/options/optionsExtNames.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getCountryFlagsPresetName, getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { getCurrentCampaignMission, setCurrentCampaignMission } = require("%scripts/missions/startMissionsList.nut")
let { debug_dump_stack } = require("dagor.debug")

const MIN_SLIDE_TIME = 2.0

add_event_listener("FinishLoading", function(_p) {
  stop_gui_sound("slide_loop")
  loading_stop_voice()
  loading_stop_music()
})

gui_handlers.LoadingBrief <- class (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/loading/loadingCamp.blk"
  sceneNavBlkName = "%gui/loading/loadingNav.blk"

  gm = 0
  gt = 0

  function initScreen() {
    this.gm = get_game_mode()
    this.gt = get_game_type_by_mode(this.gm)

    set_presence_to_player("loading")
    setHelpTextOnLoading(this.scene.findObject("scene-help"))

    let blk = get_game_params_blk()
    if ("loading" in blk && "numTips" in blk.loading)
      this.numTips = blk.loading.numTips

    let cutObj = this.guiScene["cutscene_update"]
    if (checkObj(cutObj))
      cutObj.setUserData(this)

    setDoubleTextToButton(this.scene, "btn_select", loc("hints/cutsc_skip"))

    let missionBlk = DataBlock()
    local country = ""
    if (getCurrentCampaignMission() || is_mplayer_peer()) {
      if (is_mplayer_peer()) {
        get_current_mission_desc(missionBlk)
        setCurrentCampaignMission(missionBlk.getStr("name", ""))
      }
      else if (get_game_type() & GT_DYNAMIC)
        missionBlk.setFrom(::mission_settings.mission)
      else {
        let missionName = getCurrentCampaignMission()
        let missionInfoBlk = getUrlOrFileMissionMetaInfo(missionName, this.gm)
        if (missionInfoBlk != null)
          missionBlk.setFrom(missionInfoBlk)
        else {
          let gMode = this.gm // warning disable: -declared-never-used
          debug_dump_stack()
          logerr("[LoadingBrief] Missing mission blk")
        }
      }

      if (this.gm == GM_TEST_FLIGHT)
        country = ::getCountryByAircraftName(::get_test_flight_unit_info()?.unit.name)
      else
        country = ::getCountryByAircraftName(missionBlk.getStr("player_class", ""))
      log($"0 player_class = {missionBlk.getStr("player_class", "")}; country = {country}")
      if (country != "" && !(get_game_type() & GT_VERSUS) && this.gm != GM_TRAINING)
        this.guiScene["briefing-flag"]["background-image"] = getCountryFlagImg($"bgflag_{country}")

      this.misObj_add = this.count_misObj_add(missionBlk)
    }

    this.partsList = []
    if (this.briefing) {
      let guiBlk = GUI.get()
      let exclBlock = guiBlk?.slides_exclude?[getCountryFlagsPresetName()]
      let excludeArray = exclBlock ? (exclBlock % "name") : []

      local sceneInfo = ""
      let currentCampaignMission = getCurrentCampaignMission()
      if (currentCampaignMission) {
        sceneInfo = loc($"mb/{currentCampaignMission}/date", "")
        sceneInfo = "".concat(sceneInfo, sceneInfo == "" ? "" : "\n", loc($"mb/{currentCampaignMission}/place", ""))
      }
      if (sceneInfo == "")
        sceneInfo = loc(this.briefing.getStr("place_loc", ""))
      this.setSceneInfo(sceneInfo)

      this.music = this.briefing.getStr("music", "action_01")
      if ((get_game_type() & GT_DYNAMIC) && country != "")
        this.music =$"{country}_main_theme"

      local prevSlide = ""

      for (local i = 0; i < this.briefing.blockCount(); i++) {
        let partBlock = this.briefing.getBlock(i);
        if (partBlock.getBlockName() == "part") {
          let part =
          {
            subtitles = loc(partBlock.getStr("event", ""))
            slides = []
          }
          part.event <- partBlock.getStr("event", "")
          for (local idx = part.event.indexof("/"); idx;)
            if (idx != null) {
              part.event = $"{part.event.slice(0, idx)}_{part.event.slice(idx + 1)}"
              idx = part.event.indexof("/")
            }
          part.voiceLen <- loading_get_voice_len(part.event) //-1 if there's no sound
          log($"voice {part.event} len {part.voiceLen}")

          local totalSlidesTime = 0.0
          let freeTimeSlides = []
          foreach (slideBlock in partBlock % "slide") {
            let image = slideBlock.getStr("picture", "")
            if (image != "") {
              if (find_in_array(excludeArray, image, -1) >= 0) {
                log($"EXCLUDE by: {getCountryFlagsPresetName()}; slide {image}")
                continue
              }
            }
            let slide = {
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

          if (!part.slides.len()) {
            local partTime = part.voiceLen
            if (partTime <= 0)
              partTime = (partBlock?.minTime ?? 0).tofloat()
            part.slides.append({
              time = max(partTime, MIN_SLIDE_TIME)
              image = prevSlide
              map = false
            })
          }
          else if (part.voiceLen > totalSlidesTime) {
            if (freeTimeSlides.len()) {
              let slideTimeDiff = (part.voiceLen - totalSlidesTime) / freeTimeSlides.len()
              foreach (slide in freeTimeSlides)
                slide.time += slideTimeDiff
            }
            else if (totalSlidesTime) {
              let slideTimeMul = part.voiceLen / totalSlidesTime
              foreach (slide in part.slides)
                slide.time *= slideTimeMul
            }
          }

          this.partsList.append(part)
        }
      }
    }
    if (this.partsList.len() == 0)
      this.finished = true

    if (gchat_is_enabled() && hasMenuChat.value)
      ::switchMenuChatObjIfVisible(::getChatDiv(this.scene))

    if (this.gt & GT_VERSUS) {
      let missionHelpPath = g_mission_type.getHelpPathForCurrentMission()
      let controlHelpName = g_mission_type.getControlHelpName()
      let haveHelp = hasFeature("ControlsHelp")
        && (missionHelpPath != null || controlHelpName != null)

      let helpBtnObj = showObjById("btn_help", haveHelp, this.scene)
      if (helpBtnObj && !showConsoleButtons.value)
        helpBtnObj.setValue("".concat(loc("flightmenu/btnControlsHelp"), loc("ui/parentheses/space", { text = "F1" })))

      if (haveHelp) {
        let parts = missionHelpPath != null
          ? split_by_chars(missionHelpPath, "/.")
          : null
        let helpId = parts != null
          ? parts.len() >= 2 ? parts[parts.len() - 2] : ""
          : controlHelpName
        let cfgPath = $"seen/help_mission_type/{helpId}"
        let isSeen = loadLocalByAccount(cfgPath, 0)
        if (!isSeen) {
          this.onHelp()
          saveLocalByAccount(cfgPath, 1)
        }
      }
    }
  }

  function count_misObj_add(blk) {
    let res = []

    local m_aircraft = blk.getStr("player_class", "")
    local m_weapon = blk.getStr("player_weapons", "")

    if (this.gm == GM_TEST_FLIGHT) {
      m_aircraft = ::get_test_flight_unit_info()?.unit.name
      m_weapon = get_gui_option(USEROPT_WEAPONS)
    }
    if ((m_aircraft != "") && !(this.gt & GT_VERSUS))
      res.append("".concat(loc("options/aircraft"), loc("ui/colon"), " ",
        getUnitName(m_aircraft), "; ", getWeaponNameText(m_aircraft, null, m_weapon, ", ")))

    local m_condition = ""
    let currentCampaignMission = getCurrentCampaignMission()
    if (currentCampaignMission)
      m_condition = loc($"missions/{currentCampaignMission}/condition", "")

    if (m_condition == "") {
      if (!(this.gt & GT_VERSUS)) {
        let m_location = blk.getStr("locationName", map_to_location(blk.getStr("level", "")))
        if (m_location != "")
          m_condition = loc($"location/{m_location}")
        let m_time = blk.getStr("time", blk.getStr("environment", ""))
        if (m_time != "")
          m_condition = "".concat(m_condition, m_condition != "" ? "; " : "", getMissionTimeText(m_time))
        let m_weather = blk.getStr("weather", "")
        if (m_weather != "")
          m_condition = "".concat(m_condition, m_condition != "" ? "; " : "", getWeatherLocName(m_weather))
      }
    }
    if (m_condition != "")
      res.append("".concat(loc("sm_conditions"), loc("ui/colon"), " ", m_condition))
    return "\n".join(res, true)
  }

  function onUpdate(_obj, dt) {
    if (!this.finished)
      this.slidesUpdate(dt)

    if (this.nextSlideImg && this.isSlideReady()) {
      this.showSlide()
      this.checkNewSubtitles()
    }

    if (this.waitForMap)
      this.showMap()

    if (this.applyReady != loading_is_finished()) {
      this.applyReady = loading_is_finished()
      let showStart = !::is_multiplayer() && this.gm != GM_TRAINING && !changeStartMission
      if ((this.applyReady && !showStart) || this.finished)
        this.finishLoading()
      else {
        showObjById("btn_select", this.applyReady && showStart, this.scene)
        showObjById("loadanim", !this.applyReady, this.scene)
      }
    }

    if (this.finished && (!this.waitForMap)) {  //tipsUpdate
      this._tipTime -= dt
      if (this.tipShow && (this._tipTime < 0)) {
        this.setSceneInfo("")
        this.tipShow = false
      }
      if (this._tipTime < -1) {
        this._tipTime = this.tipShowTime
        this.tipShow = true
        this.setSceneInfo(getTip())
      }
    }
  }

  function checkNewSubtitles() {
    if (this.nextSubtitles) {
      this.setSubtitles(this.nextSubtitles)
      this.nextSubtitles = null
    }
  }

  function slidesUpdate(dt) {
    this.slideTime -= dt
    if (this.slideTime <= 0)
      this.checkNextSlide()
  }

  function checkNextSlide() {
    let isLastSlideInPart = this.slideIdx >= this.partsList[this.partIdx].slides.len() - 1
    if (isLastSlideInPart && loading_is_voice_playing())
      return

    if (!this.slidesStarted) {
      this.slidesStarted = true
      this.onSlidesStart()
    }

    if (!isLastSlideInPart)
      this.slideIdx++
    else {
      this.partIdx++
      this.setSubtitles("")
      if (this.partIdx >= this.partsList.len() || !this.partsList[this.partIdx].slides.len()) {
        this.setFinished()
        if (loading_is_finished())
          this.finishLoading()
        return
      }
      else {
        this.slideIdx = 0
        this.nextSubtitles = this.partsList[this.partIdx].subtitles
        loading_stop_voice_but_named_events()
        loading_play_voice(this.partsList[this.partIdx].event, true)
        log($"loading_play_voice {this.partsList[this.partIdx].event.tostring()}")
      }
    }

    //next Slide show
    let curSlide = this.partsList[this.partIdx].slides[this.slideIdx]

    this.slideTime = curSlide.time

    if (curSlide.map)
      this.showMap()
    else
      this.setSlide(curSlide.image)
  }

  function setFinished() {
    this.finished = true
    this.showMap()
  }

  function onSlidesStart() {
    this.setSceneTitle(::getCurMpTitle())
    if (this.partsList.len() > 0) {
      this.setSubtitles(this.partsList[0].subtitles)
      loading_play_music(this.music)
      loading_play_voice(this.partsList[0].event, true)
      log($"loading_play_voice {this.partsList[0].event.tostring()}")
    }
    start_gui_sound("slide_loop")
  }

  function setSlide(imgName) {
    this.nextSlideImg = (imgName != "") ? imgName : null
    this.hideSlide()
  }

  function hideSlide() {
    this.guiScene["slide-place"].animShow = "hide"
    if (!this.hideSoundPlayed) {
      this.guiScene.playSound("slide_in")
      this.hideSoundPlayed = true
    }
  }

  function showSlide() {
    this.showProjectorGlow(true)
    this.showProjectorSmallGlow(false)
    let place = this.guiScene["slide-place"]
    place.animShow = "show"
    this.guiScene.playSound("slide_out")
    this.hideSoundPlayed = false
    if (this.nextSlideImg) {
      this.guiScene["slide-img"]["background-image"] = $"ui/slides/{this.nextSlideImg}?P1"
      place.rotation = (2.0 * frnd() - 1.0).tostring()
      place.padding = format("%fsh, %fsh, 0, 0", 0.1 * (frnd() - 0.5), 0.05 * (frnd() - 0.5))
      this.nextSlideImg = null
    }
  }

  function showProjectorGlow(show) {
    if (this.guiScene["briefingglow"])
      this.guiScene["briefingglow"].show(show)
  }
  function showProjectorSmallGlow(show) {
    if (this.guiScene["briefingsmallglow"])
      this.guiScene["briefingsmallglow"].show(show)
  }

  function isSlideReady() {
    return (this.guiScene["slide-place"]["_pos-timer"] == "0")
  }

  function setSceneInfo(text) {
    this.safeSetValue("scene-info", text)
  }

  function setSubtitles(text) {
    this.safeSetValue("scene-subtitles", text)
  }

  function showMap() {
    if (this.isSlideReady()) {
      this.showProjectorGlow(false)
      this.showProjectorSmallGlow(true)
      this.checkNewSubtitles()
      this.waitForMap = false
      if (this.briefing) {
        local misObj = ""
        let currentCampaignMission = getCurrentCampaignMission()
        if (currentCampaignMission)
          misObj = loc($"mb/{currentCampaignMission}/objective", "")
        if ((this.gt & GT_VERSUS) && currentCampaignMission)
          misObj = ::loc_current_mission_desc()
        if (misObj == "" && currentCampaignMission)
          misObj = loc($"missions/{currentCampaignMission}/objective", "")
        if (misObj == "")
          misObj = loc(this.briefing.getStr("objective_loc", ""))
        if (this.misObj_add != "")
          misObj = "".concat(misObj, misObj.len() ? "\n\n" : "", this.misObj_add)

        misObj = "".concat(colorize("userlogColoredText", locCurrentMissionName(false)),
          "\n\n", clearBorderSymbolsMultiline(misObj))
        this.setMissionObjective(misObj)
      }

      if (this.guiScene["map-background"])
        this.guiScene["map-background"].show(true)
      if (this.guiScene["darkscreen"])
        this.guiScene["darkscreen"].animShow = "show"
      this.setSceneInfo("")

      let obj = this.guiScene?["tactical-map"]
      if (obj) {
        if (obj?.animShow != "show")
          this.guiScene.playSound("show_map")
        obj.animShow = "show"
        obj.show(true)
      }
    }
    else {
      this.hideSlide()
      this.waitForMap = true
    }
  }

  function setMissionObjective(text) {
    this.safeSetValue("mission-objectives", text)
  }

  function safeSetValue(objName, value) {
    let show = (value != null) && (value != "")
    let obj = this.guiScene[objName]
    if (obj) {
      if (show)
        obj.setValue(value)
      obj.animShow = (show) ? "show" : "hide"
    }
  }

  function onHelp(_obj = null) {
    ::gui_modal_help(false, HELP_CONTENT_SET.LOADING)
  }

  function onApply(_obj) {
    loading_stop_voice()
    loading_stop_music()
    loading_press_apply()
  }

  function finishLoading() {
    loading_stop_voice()
    loading_stop_music()
    briefing_finish()
  }

  function onTestBack(_obj) {
    this.goForward(gui_start_mainmenu)
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