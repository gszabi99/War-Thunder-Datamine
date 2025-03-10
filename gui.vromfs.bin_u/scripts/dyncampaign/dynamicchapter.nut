from "%scripts/dagui_natives.nut" import get_mission_progress
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { getFullUnlockDescByName } = require("%scripts/unlocks/unlocksViewModule.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_option } = require("guiOptions")
let { dynamicInit, dynamicGetList } = require("dynamicMission")
let { get_cur_game_mode_name } = require("mission")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_DYNAMIC, USEROPT_YEAR, USEROPT_MP_TEAM_COUNTRY,
  USEROPT_DYN_FL_ADVANTAGE, USEROPT_DYN_WINS_TO_COMPLETE, USEROPT_DIFFICULTY
} = require("%scripts/options/optionsExtNames.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { get_game_settings_blk } = require("blkGetters")
let { getDynamicLayouts, addMissionListFull } = require("%scripts/missions/missionsUtils.nut")
let { DYNAMIC_REQ_COUNTRY_RANK, guiStartDynamicSummary, guiStartCdOptions
} = require("%scripts/missions/startMissionsList.nut")
let { set_current_campaign, get_mission_settings, set_mission_settings } = require("%scripts/missions/missionsStates.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")

gui_handlers.DynamicLayouts <- class (gui_handlers.CampaignChapter) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/backSelectNavChapter.blk"

  wndOptionsMode = OPTIONS_MODE_DYNAMIC
  wndGameMode = GM_DYNAMIC

  descItems = ["name", "maintext"]
  yearsArray = []
  missions = []
  prevSelect = null

  function initScreen() {
    this.guiScene.replaceContent(this.scene.findObject("mission_desc"), "%gui/missionDescr.blk", null)
    let headerTitle = this.scene.findObject("chapter_name")
    headerTitle.setValue(loc("mainmenu/btnDynamic"))
    showObjById("btn_back", false, this.scene.findObject("nav-help"))
    this.yearsArray = get_option(USEROPT_YEAR).values

    this.scene.findObject("optionlist-container").mislist = "yes"

    this.updateMouseMode()
    this.initDescHandler()
    this.initMissionsList()
    move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  }

  function initMissionsList(...) {
    this.missions = []
    this.add_missions()
    let listObj = this.scene.findObject("items_list")
    let missionsList = this.generateMissionsList()

    this.guiScene.replaceContentFromText(listObj, missionsList, missionsList.len(), this)
    for (local i = 0; i < listObj.childrenCount(); i++)
      listObj.getChild(i).setIntProp(this.listIdxPID, i)
    listObj.setValue(this.missions.len() ? 0 : -1)

    this.refreshMissionDesc()
  }

  function add_missions() {
    let mission_array = getDynamicLayouts()
    local unlockedMissionCount = 0

    for (local j = 0; j < mission_array.len(); j++) {
      let misDescr = {}
      misDescr.map <- mission_array[j].mis_file
      misDescr.locName <- $"dynamic/{mission_array[j].name}"

      let misBlk = DataBlock()
      misBlk.load(misDescr.map)

      misDescr.unlocks <- {}
      misDescr.unlocks.country <- {}
      misDescr.unlocks.years <- {}

      misDescr.id <- misBlk.mission_settings.mission.name
      let countries = [ misBlk.mission_settings.mission.country_allies
                          misBlk.mission_settings.mission.country_axis
                        ]
      for (local i = countries.len() - 1; i >= 0; i--)
        if (!::is_dynamic_country_allowed(countries[i]))
          countries.remove(i)
      if (!countries.len())
        continue

      misDescr.countries <- countries

      local isAnyCountryUnlocked = false
      local isAnyYearUnlocked = false
      local lockReason = ""
      foreach (_idx, country in misDescr.countries) {
        let countryId = $"{misDescr.id}_{country}"
        local isCountryUnlocked = isUnlockOpened(countryId, UNLOCKABLE_DYNCAMPAIGN)
        if (!isCountryUnlocked)
          lockReason = "".concat(lockReason, (lockReason.len() ? "\n" : ""),
            getFullUnlockDescByName(countryId), "\n")
        else {
          foreach (year in this.yearsArray) {
            local is_unlocked = false
            let yearId = $"country_{country}_{year}"
            if (isUnlockOpened(yearId, UNLOCKABLE_YEAR)) {
              isAnyYearUnlocked = true
              is_unlocked = true
            }
            misDescr.unlocks.years[yearId] <- is_unlocked
          }

          if (!isAnyYearUnlocked)
            lockReason = "".concat(lockReason,
              getFullUnlockDescByName($"country_{country}_{this.yearsArray[0]}"))

          isAnyCountryUnlocked = isAnyYearUnlocked
          isCountryUnlocked = isAnyYearUnlocked
        }
        misDescr.unlocks.country[countryId] <- isCountryUnlocked
      }

      let nameId =$"dynamic/{misDescr.id}"
      misDescr.unlockText <- lockReason
      misDescr.progress <- isAnyCountryUnlocked ? get_mission_progress(nameId) : -1

      if (misDescr.progress == -1)
        this.missions.append(misDescr)
      else
        this.missions.insert(unlockedMissionCount++, misDescr)
    }
  }

  function generateMissionsList() {
    let view = { items = [] }
    foreach (idx, mission in this.missions) {
      local elemCssId = "mission_item_locked"
      local medalIcon = "#ui/gameuiskin#locked.svg"
      let nameId = $"dynamic/{mission.id}"
      let progress = mission.progress
      if (0 == progress) {
        elemCssId = "mission_item_completed"
        medalIcon = "#ui/gameuiskin#mission_complete_arcade"
      }
      else if (1 == progress) {
        elemCssId = "mission_item_completed"
        medalIcon = "#ui/gameuiskin#mission_complete_realistic"
      }
      else if (2 == progress) {
        elemCssId = "mission_item_completed"
        medalIcon = "#ui/gameuiskin#mission_complete_simulator"
      }
      else if (3 == progress) {
        elemCssId = "mission_item_unlocked"
        medalIcon = ""
      }

      view.items.append({
        itemTag = elemCssId
        itemIcon = medalIcon
        id = mission.id
        isSelected = idx == 0
        itemText = $"#{nameId}"
        isNeedOnHover = showConsoleButtons.value
      })
    }

    return handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
  }

  function refreshMissionDesc() {
    let missionBlock = this.missions?[this.getSelectedMission()]
    if (missionBlock != null && missionBlock?.descConfig == null)
      missionBlock.descConfig <- this.buildMissionDescConfig(missionBlock)
    if (this.missionDescWeak)
      this.missionDescWeak.applyDescConfig(missionBlock?.descConfig ?? {})
    this.updateButtons()
  }

  function buildMissionDescConfig(missionBlock) {
    let config = { countries = "" }
    local isAnyCountryUnlocked = false
    if (missionBlock) {
      config.name <- loc(missionBlock.locName)
      local reqText = missionBlock.unlockText
      foreach (_idx, country in missionBlock.countries) {
        let countryUnlocked = this.checkCountry(country) && missionBlock.unlocks.country[$"{missionBlock.id}_{country}"]
        config.countries = "".concat(config.countries, format("optionImg{ background-image:t='%s'; enable:t='%s' } ",
          getCountryIcon($"country_{country}", true), countryUnlocked ? "yes" : "no"))

        isAnyCountryUnlocked = isAnyCountryUnlocked || countryUnlocked
      }

      let reqTitle = isAnyCountryUnlocked ? loc("dynamic/requireForUnlockCountry") : loc("dynamic/requireForUnlock")
      if (reqText != "")
        reqText = "".concat("<color=@badTextColor>", reqTitle, loc("ui/colon"), "\n", reqText, "</color>\n")
      config.maintext <- "".concat(reqText, loc($"dynamic/{missionBlock.id}/desc", ""))
      config.canStart <- isAnyCountryUnlocked
    }
    return config
  }

  function checkCountry(country) {
    let missionBlock = this.missions[this.getSelectedMission()]
    let countryId = $"{missionBlock.id}_{country}"
    if (!(countryId in missionBlock.unlocks.country)) {
      assert(false,$"Not found unlock {countryId}")
      debugTableData(missionBlock.countries)
      return false
    }
    return true
  }

  function updateButtons() {
    let selectedMission = this.missions?[this.getSelectedMission()]

    let hoveredMission = this.isMouseMode ? null : this.missions?[this.hoveredIdx]
    let isCurItemInFocus = this.isMouseMode || (hoveredMission != null && hoveredMission == selectedMission)

    showObjById("btn_select_console", !isCurItemInFocus && hoveredMission != null, this.scene)

    let canStart = isCurItemInFocus && (selectedMission?.descConfig.canStart ?? false)
    showObjById("btn_start", isCurItemInFocus && selectedMission != null, this.scene)
    this.scene.findObject("btn_start").enable(canStart)
  }

  function onEventSquadStatusChanged(_params) {
    this.doWhenActiveOnce("updateButtons")
  }

  function getSelectedMission() {
    let list = this.scene.findObject("items_list")
    if (checkObj(list))
      return list.getValue()
    return -1
  }

  function onItemSelect(_obj) {
    this.refreshMissionDesc()
  }

  function onStart() {
    if (!::g_squad_utils.canJoinFlightMsgBox({ msgId = "multiplayer/squad/cantJoinSessionWithSquad" }))
      return

    let index = this.getSelectedMission()
    let missionBlock = this.missions[index]
    local isAnyCountryUnlocked = false

    foreach (_cName, countryUnlocked in missionBlock.unlocks.country) {
      if (countryUnlocked && missionBlock.unlocks.years.len())
        foreach (_yName, yearUnlocked in missionBlock.unlocks.years)
          if (yearUnlocked) {
            isAnyCountryUnlocked = true
            break
          }
      isAnyCountryUnlocked = countryUnlocked || isAnyCountryUnlocked
    }

    if (isAnyCountryUnlocked) {
      set_current_campaign(missionBlock)
      set_mission_settings("layout", this.missions[index].map)
      this.openMissionOptions()
    }
  }

  function openMissionOptions() {
    let options =   [
      [USEROPT_MP_TEAM_COUNTRY, "combobox"],
      [USEROPT_YEAR, "combobox"],
      [USEROPT_DYN_FL_ADVANTAGE, "spinner"],
      [USEROPT_DYN_WINS_TO_COMPLETE, "spinner"],
      [USEROPT_DIFFICULTY, "spinner"]
    ]

    this.createModalOptions(options, Callback(this.checkCustomDifficulty, this))
  }

  function finalApplyCallback() {
    this.finalApply()
    if (get_mission_settings().dynlist.len() == 0)
      this.msgBox("no_missions_error", loc("msgbox/appearError"),
        [["ok", this.goBack ]], "ok", { cancel_fn = this.goBack });
  }

  function checkCustomDifficulty() {
    let diffCode = get_mission_settings().diff
    if (!::check_diff_pkg(diffCode))
      return

    this.checkedNewFlight(function() {
      if (get_gui_option(USEROPT_DIFFICULTY) == "custom")
        guiStartCdOptions(this.finalApplyCallback, this)
      else
        this.finalApplyCallback()
    })
  }

  function finalApply() {
    let map = get_mission_settings().layout

    local desc = get_option(USEROPT_MP_TEAM_COUNTRY);
    let team = desc.values[desc.value];
    let settings = DataBlock();
    settings.setInt("playerSide", team)

    
    

    
    

    
    

    desc = get_option(USEROPT_DYN_FL_ADVANTAGE);
    settings.setInt("frontlineAdvantage", desc.values[desc.value])

    desc = get_option(USEROPT_DYN_WINS_TO_COMPLETE);
    settings.setInt("needWinsToComplete", desc.values[desc.value]);

    desc = get_option(USEROPT_YEAR);
    settings.setStr("year", desc.values[desc.value]);

    desc = get_option(USEROPT_DIFFICULTY)
    set_mission_settings("diff", desc.value)
    settings.setInt("difficulty", desc.value);

    dynamicInit(settings, map)
    let dynListBlk = DataBlock();
    set_mission_settings("dynlist", dynamicGetList(dynListBlk, false))

    local playerCountry = ""

    let add = []
    for (local i = 0; i < get_mission_settings().dynlist.len(); i++) {
      let misblk = get_mission_settings().dynlist[i].mission_settings.mission
      misblk.setStr("mis_file", map)
      misblk.setStr("chapter", get_cur_game_mode_name())
      misblk.setStr("type", get_cur_game_mode_name())
      add.append(misblk)

      if (playerCountry == "")
        playerCountry = misblk.getStr(team == 1 ? "country_allies" : "country_axis", "ussr")
    }
    addMissionListFull(GM_DYNAMIC, add, get_mission_settings().dynlist)
    ::first_generation = true

    this.goForwardCheckEntitlement(guiStartDynamicSummary, {
      minRank = DYNAMIC_REQ_COUNTRY_RANK
      rankCountry = playerCountry
      silentFeature = "ModeDynamic"
    })
  }

  function goBack() {
    base.goBack()
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function onFav() {}
}


::is_dynamic_country_allowed <- function is_dynamic_country_allowed(country) {
  let sBlk = get_game_settings_blk()
  let list = sBlk?.dynamicCountries

  if (!list || !list.paramCount())
    return true
  return list?[country] == true
}

::get_mission_team_countries <- function get_mission_team_countries(layout) {
  local res = null
  if (!layout)
    return res

  let lblk = DataBlock()
  lblk.load(layout)
  let mBlk = lblk?.mission_settings.mission
  if (!mBlk)
    return res

  let checkDynamic = mBlk?.type == "dynamic"

  res = []
  foreach (cTag in ["country_allies", "country_axis"]) {
    local c = mBlk?[cTag] ?? "ussr"
    if (!checkDynamic || ::is_dynamic_country_allowed(c))
      c = $"country_{c}"
    else
      c = null
    res.append(c)
  }
  return res
}

