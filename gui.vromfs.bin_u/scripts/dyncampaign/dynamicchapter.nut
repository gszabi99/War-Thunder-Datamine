from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { getFullUnlockDescByName } = require("%scripts/unlocks/unlocksViewModule.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_gui_option } = require("guiOptions")
::dynamic_req_country_rank <- 1

::gui_start_dynamic_layouts <- function gui_start_dynamic_layouts() {
  ::handlersManager.loadHandler(::gui_handlers.DynamicLayouts)
}

::gui_handlers.DynamicLayouts <- class extends ::gui_handlers.CampaignChapter
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/backSelectNavChapter.blk"

  wndOptionsMode = ::OPTIONS_MODE_DYNAMIC
  wndGameMode = GM_DYNAMIC

  descItems = ["name", "maintext"]
  yearsArray = []
  missions = []
  prevSelect = null

  function initScreen()
  {
    this.guiScene.replaceContent("mission_desc", "%gui/missionDescr.blk")
    let headerTitle = this.scene.findObject("chapter_name")
    headerTitle.setValue(loc("mainmenu/btnDynamic"))
    ::showBtn("btn_back", false, this.scene.findObject("nav-help"))
    yearsArray = ::get_option(::USEROPT_YEAR).values

    this.scene.findObject("optionlist-container").mislist = "yes"

    this.updateMouseMode()
    this.initDescHandler()
    initMissionsList()
    ::move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  }

  function initMissionsList(...)
  {
    missions = []
    add_missions()
    let listObj = this.scene.findObject("items_list")
    let missionsList = generateMissionsList()

    this.guiScene.replaceContentFromText(listObj, missionsList, missionsList.len(), this)
    for (local i = 0; i < listObj.childrenCount(); i++)
      listObj.getChild(i).setIntProp(this.listIdxPID, i)
    listObj.setValue(missions.len() ? 0 : -1)

    refreshMissionDesc()
  }

  function add_missions()
  {
    let mission_array = ::get_dynamic_layouts()
    local unlockedMissionCount = 0

    for (local j = 0; j < mission_array.len(); j++)
    {
      let misDescr = {}
      misDescr.map <- mission_array[j].mis_file
      misDescr.locName <- "dynamic/" + mission_array[j].name

      let misBlk = ::DataBlock()
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
      foreach (_idx, country in misDescr.countries)
      {
        let countryId = misDescr.id + "_" + country
        local isCountryUnlocked = ::is_unlocked_scripted(UNLOCKABLE_DYNCAMPAIGN, countryId)
        if (!isCountryUnlocked)
          lockReason += (lockReason.len() ? "\n" : "") + getFullUnlockDescByName(countryId) + "\n"
        else
        {
          foreach (year in yearsArray)
          {
            local is_unlocked = false
            let yearId = "country_" + country + "_" + year
            if (::is_unlocked_scripted(UNLOCKABLE_YEAR, yearId))
            {
              isAnyYearUnlocked = true
              is_unlocked = true
            }
            misDescr.unlocks.years[yearId] <- is_unlocked
          }

          if (!isAnyYearUnlocked)
            lockReason += getFullUnlockDescByName($"country_{country}_{yearsArray[0]}")

          isAnyCountryUnlocked = isAnyYearUnlocked
          isCountryUnlocked = isAnyYearUnlocked
        }
        misDescr.unlocks.country[countryId] <- isCountryUnlocked
      }

      let nameId = "dynamic/" + misDescr.id
      misDescr.unlockText <- lockReason
      misDescr.progress <- isAnyCountryUnlocked ? ::get_mission_progress(nameId) : -1

      if (misDescr.progress == -1)
        missions.append(misDescr)
      else
        missions.insert(unlockedMissionCount++, misDescr)
    }
  }

  function generateMissionsList()
  {
    let view = { items = [] }
    foreach(idx, mission in missions)
    {
      local elemCssId = "mission_item_locked"
      local medalIcon = "#ui/gameuiskin#locked.svg"
      let nameId = "dynamic/" + mission.id
      switch (mission.progress)
      {
        case 0:
          elemCssId = "mission_item_completed"
          medalIcon = "#ui/gameuiskin#mission_complete_arcade.png"
          break
        case 1:
          elemCssId = "mission_item_completed"
          medalIcon = "#ui/gameuiskin#mission_complete_realistic.png"
          break
        case 2:
          elemCssId = "mission_item_completed"
          medalIcon = "#ui/gameuiskin#mission_complete_simulator.png"
          break
        case 3:
          elemCssId = "mission_item_unlocked"
          medalIcon = ""
          break
      }

      view.items.append({
        itemTag = elemCssId
        itemIcon = medalIcon
        id = mission.id
        isSelected = idx == 0
        itemText = "#" + nameId
        isNeedOnHover = ::show_console_buttons
      })
    }

    return ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
  }

  function refreshMissionDesc()
  {
    let missionBlock = missions?[getSelectedMission()]
    if (missionBlock != null && missionBlock?.descConfig == null)
      missionBlock.descConfig <- buildMissionDescConfig(missionBlock)
    if (this.missionDescWeak)
      this.missionDescWeak.applyDescConfig(missionBlock?.descConfig ?? {})
    updateButtons()
  }

  function buildMissionDescConfig(missionBlock)
  {
    let config = { countries = "" }
    local isAnyCountryUnlocked = false
    if (missionBlock)
    {
      config.name <- loc(missionBlock.locName)
      local reqText = missionBlock.unlockText
      foreach(_idx, country in missionBlock.countries)
      {
        let countryUnlocked = checkCountry(country) && missionBlock.unlocks.country[missionBlock.id + "_" + country]
        config.countries += format("optionImg{ background-image:t='%s'; enable:t='%s' } ",
                             ::get_country_icon("country_" + country, true), countryUnlocked? "yes" : "no")

        isAnyCountryUnlocked = isAnyCountryUnlocked || countryUnlocked
      }

      if(reqText != "")
        reqText = "<color=@badTextColor>" + loc("dynamic/requireForUnlock") + loc("ui/colon") + "\n" + reqText + "</color>\n"

      config.maintext <- reqText + loc("dynamic/"+ missionBlock.id + "/desc", "")
      config.canStart <- isAnyCountryUnlocked
    }
    return config
  }

  function checkCountry(country)
  {
    let missionBlock = missions[getSelectedMission()]
    let countryId = missionBlock.id + "_" + country
    if(!(countryId in missionBlock.unlocks.country))
    {
      assert(false, "Not found unlock " + countryId)
      debugTableData(missionBlock.countries)
      return false
    }
    return true
  }

  function updateButtons()
  {
    let selectedMission = missions?[getSelectedMission()]

    let hoveredMission = this.isMouseMode ? null : missions?[this.hoveredIdx]
    let isCurItemInFocus = this.isMouseMode || (hoveredMission != null && hoveredMission == selectedMission)

    this.showSceneBtn("btn_select_console", !isCurItemInFocus && hoveredMission != null)

    let canStart = isCurItemInFocus && (selectedMission?.descConfig.canStart ?? false)
    ::showBtn("btn_start", isCurItemInFocus && selectedMission != null, this.scene)
    this.scene.findObject("btn_start").enable(canStart)
  }

  function onEventSquadStatusChanged(_params)
  {
    this.doWhenActiveOnce("updateButtons")
  }

  function getSelectedMission()
  {
    let list = this.scene.findObject("items_list")
    if(checkObj(list))
      return list.getValue()
    return -1
  }

  function onItemSelect(_obj)
  {
    refreshMissionDesc()
  }

  function onStart()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({msgId = "multiplayer/squad/cantJoinSessionWithSquad"}))
      return

    let index = getSelectedMission()
    let missionBlock = missions[index]
    local isAnyCountryUnlocked = false

    foreach (_cName, countryUnlocked in missionBlock.unlocks.country)
    {
      if (countryUnlocked && missionBlock.unlocks.years.len())
        foreach (_yName, yearUnlocked in missionBlock.unlocks.years)
          if (yearUnlocked)
          {
            isAnyCountryUnlocked = true
            break
          }
      isAnyCountryUnlocked = countryUnlocked || isAnyCountryUnlocked
    }

    if(isAnyCountryUnlocked)
    {
      ::current_campaign = missionBlock
      ::mission_settings.layout = missions[index].map
      openMissionOptions()
    }
  }

  function openMissionOptions()
  {
    let options =   [
      [::USEROPT_MP_TEAM_COUNTRY, "combobox"],
      [::USEROPT_YEAR, "combobox"],
      [::USEROPT_DYN_FL_ADVANTAGE, "spinner"],
      [::USEROPT_DYN_WINS_TO_COMPLETE, "spinner"],
      [::USEROPT_DIFFICULTY, "spinner"]
    ]

    this.createModalOptions(options, Callback(checkCustomDifficulty, this))
  }

  function finalApplyCallback()
  {
    finalApply()
    if (::mission_settings.dynlist.len() == 0)
      this.msgBox("no_missions_error", loc("msgbox/appearError"),
        [["ok", goBack ]], "ok", { cancel_fn = goBack});
  }

  function checkCustomDifficulty()
  {
    let diffCode = ::mission_settings.diff
    if (!::check_diff_pkg(diffCode))
      return

    this.checkedNewFlight(function() {
      if (get_gui_option(::USEROPT_DIFFICULTY) == "custom")
        ::gui_start_cd_options(finalApplyCallback, this)
      else
        finalApplyCallback()
    })
  }

  function finalApply()
  {
    let map = ::mission_settings.layout

    local desc = ::get_option(::USEROPT_MP_TEAM_COUNTRY);
    let team = desc.values[desc.value];
    let settings = ::DataBlock();
    settings.setInt("playerSide", team)

    //desc = ::get_option(::USEROPT_DYN_ALLIES);
    //local allies = desc.values[desc.value];

    //desc = ::get_option(::USEROPT_DYN_ENEMIES);
    //local enemies = desc.values[desc.value];

    //settings.setInt("enemyCount", enemies)
    //settings.setInt("allyCount", allies)

    desc = ::get_option(::USEROPT_DYN_FL_ADVANTAGE);
    settings.setInt("frontlineAdvantage", desc.values[desc.value])

    desc = ::get_option(::USEROPT_DYN_WINS_TO_COMPLETE);
    settings.setInt("needWinsToComplete", desc.values[desc.value]);

    desc = ::get_option(::USEROPT_YEAR);
    settings.setStr("year", desc.values[desc.value]);

    desc = ::get_option(::USEROPT_DIFFICULTY)
    ::mission_settings.diff = desc.value
    settings.setInt("difficulty", desc.value);

    ::dynamic_init(settings, map);
    let dynListBlk = ::DataBlock();
    ::mission_settings.dynlist <- ::dynamic_get_list(dynListBlk, false)

    local playerCountry = ""

    let add = []
    for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
    {
      let misblk = ::mission_settings.dynlist[i].mission_settings.mission
      misblk.setStr("mis_file", map)
      misblk.setStr("chapter", ::get_cur_game_mode_name());
      misblk.setStr("type", ::get_cur_game_mode_name());
      add.append(misblk)

      if (playerCountry == "")
        playerCountry = misblk.getStr(team == 1 ? "country_allies" : "country_axis","ussr")
    }
    ::add_mission_list_full(GM_DYNAMIC, add, ::mission_settings.dynlist)
    ::first_generation <- true

    this.goForwardCheckEntitlement(::gui_start_dynamic_summary, {
      minRank = ::dynamic_req_country_rank
      rankCountry = playerCountry
      silentFeature = "ModeDynamic"
    })
  }

  function goBack()
  {
    base.goBack()
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function onFav(){}
}

//country without "country_" prefix
::is_dynamic_country_allowed <- function is_dynamic_country_allowed(country)
{
  let sBlk = ::get_game_settings_blk()
  let list = sBlk?.dynamicCountries

  if (!list || !list.paramCount())
    return true
  return list?[country] == true
}

::get_mission_team_countries <- function get_mission_team_countries(layout)
{
  local res = null
  if (!layout)
    return res

  let lblk = ::DataBlock()
  lblk.load(layout)
  let mBlk = lblk?.mission_settings.mission
  if (!mBlk)
    return res

  let checkDynamic = mBlk?.type == "dynamic"

  res = []
  foreach(cTag in ["country_allies", "country_axis"])
  {
    local c = mBlk?[cTag] ?? "ussr"
    if (!checkDynamic || ::is_dynamic_country_allowed(c))
      c = "country_" + c
    else
      c = null
    res.append(c)
  }
  return res
}
