from "%scripts/dagui_natives.nut" import add_video_seen, was_video_seen, get_game_mode_name, is_mouse_last_time_used, play_movie
from "%scripts/dagui_library.nut" import *

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { g_mislist_type } =  require("%scripts/missions/misListType.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let DataBlock = require("DataBlock")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { getMissionGroup, getMissionGroupName } = require("%scripts/missions/missionType.nut")
let { missionsListCampaignId } = require("%scripts/missions/getMissionsListCampaignId.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { saveTutorialToCheckReward } = require("%scripts/tutorials/tutorialsData.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { isGameModeCoop } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { getFullUnlockDescByName } = require("%scripts/unlocks/unlocksViewModule.nut")
let { get_gui_option } = require("guiOptions")
let { dynamicGetVisual } = require("dynamicMission")
let { select_mission, select_mission_full } = require("guiMission")
let { get_game_mode, get_game_type } = require("mission")
let { split, utf8ToLower } = require("%sqstd/string.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_DIFFICULTY } = require("%scripts/options/optionsExtNames.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { isInSessionRoom, isSessionLobbyCoop } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getDynamicLayouts, getNotPurchasedCampaigns,
  getMissionAllowedUnittypesMask, getMaxPlayersForGamemode, canPlayGamemodeBySquad
} = require("%scripts/missions/missionsUtils.nut")
let { openBrowserForFirstFoundEntitlement } = require("%scripts/onlineShop/onlineShopModel.nut")
let { guiStartDynamicSummary, briefingOptionsApply, guiStartCdOptions
} = require("%scripts/missions/startMissionsList.nut")
let { isRemoteMissionVar, currentCampaignId, currentCampaignMission, get_current_campaign, get_mission_settings, set_mission_settings,
  is_user_mission
} = require("%scripts/missions/missionsStates.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { guiStartMpLobby } = require("%scripts/matchingRooms/sessionLobbyManager.nut")
let { getMisListType } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"
let MODIFICATION_TUTORIAL_CHAPTERS = ["tutorial_aircraft_modification", "tutorial_tank_modification"]

enum MIS_PROGRESS { 
  COMPLETED_ARCADE    = 0
  COMPLETED_REALISTIC = 1
  COMPLETED_SIMULATOR = 2
  UNLOCKED            = 3 
  LOCKED              = 4
}


let CampaignChapter = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  applyAtClose = false

  missions = []
  curMission = null
  curMissionIdx = -1
  missionDescWeak = null

  listIdxPID = dagui_propid_add_name_id("listIdx")
  hoveredIdx = -1
  isMouseMode = true

  misListType = g_mislist_type.BASE
  canSwitchMisListType = false

  isOnlyFavorites = false

  gm = GM_SINGLE_MISSION
  missionName = null
  missionBlk = null
  isRestart = false

  canCollapseCampaigns = false
  canCollapseChapters = false

  showAllCampaigns = false

  collapsedCamp = []

  filterDataArray = []
  filterText = ""

  needCheckDiffAfterOptions = false
  applyFilterTimer = null

  function initScreen() {
    this.showWaitAnimation(true)

    this.gm = get_game_mode()
    this.loadCollapsedChapters()
    this.initCollapsingOptions()

    this.updateMouseMode()
    this.initMisListTypeSwitcher()
    this.updateFavorites()
    this.initDescHandler()
    this.updateWindow()
    move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  }

  function initDescHandler() {
    let descHandler = gui_handlers.MissionDescription.create(this.getObj("mission_desc"), this.curMission)
    this.registerSubHandler(descHandler)
    this.missionDescWeak = descHandler.weakref()
  }

  function initCollapsingOptions() {
    this.canCollapseCampaigns = this.gm != GM_SKIRMISH
    this.canCollapseChapters = this.gm == GM_SKIRMISH
  }

  function loadCollapsedChapters() {
    let collapsedList = loadLocalAccountSettings(this.getCollapseListSaveId(), "")
    this.collapsedCamp = split(collapsedList, ";")
  }

  function saveCollapsedChapters() {
    saveLocalAccountSettings(this.getCollapseListSaveId(), ";".join(this.collapsedCamp, true))
  }

  function getCollapseListSaveId() {
    return $"mislist_collapsed_chapters/{get_game_mode_name(this.gm)}"
  }

  function updateWindow() {
    local title = ""
    if (this.gm == GM_CAMPAIGN)
      title = loc("mainmenu/btnCampaign")
    else if (this.gm == GM_SINGLE_MISSION)
      title = (this.canSwitchMisListType || this.misListType != g_mislist_type.UGM)
              ? loc("mainmenu/btnSingleMission")
              : loc("mainmenu/btnUserMission")
    else if (this.gm == GM_SKIRMISH)
      title = loc("mainmenu/btnSkirmish")
    else
      title = loc($"chapters/{currentCampaignId.get()}")

    this.initMissionsList(title)
  }

  function initMissionsList(title) {
    let customChapterId = (this.gm == GM_DYNAMIC) ? currentCampaignId.get() : missionsListCampaignId.value
    local customChapters = null
    if (!this.showAllCampaigns && (this.gm == GM_CAMPAIGN || this.gm == GM_SINGLE_MISSION))
      customChapters = get_current_campaign()

    if (this.gm == GM_DYNAMIC) {
      let info = DataBlock()
      dynamicGetVisual(info)
      let l_file = info.getStr("layout", "")
      let dynLayouts = getDynamicLayouts()
      for (local i = 0; i < dynLayouts.len(); i++)
        if (dynLayouts[i].mis_file == l_file) {
          title = loc($"dynamic/{dynLayouts[i].name}")
          break
        }
    }

    let obj = this.getObj("chapter_name")
    if (obj != null)
      obj.setValue(title)

    this.misListType.requestMissionsList(this.showAllCampaigns,
      Callback(this.updateMissionsList, this),
      customChapterId, customChapters)
  }

  function updateMissionsList(new_missions) {
    this.showWaitAnimation(false)

    this.missions = new_missions
    if (this.missions.len() <= 0 && !this.canSwitchMisListType && !this.misListType.canBeEmpty) {
      this.msgBox("no_missions", loc("missions/no_missions_msgbox"), [["ok"]], "ok")
      this.goBack()
      return
    }

    this.fillMissionsList()
  }

  function fillMissionsList() {
    let listObj = this.getObj("items_list")
    if (!listObj)
      return

    let selMisConfig = this.curMission || this.misListType.getCurMission()

    let view = { items = [] }
    local selIdx = -1
    local foundCurrent = false
    local hasVideoToPlay = false

    foreach (idx, mission in this.missions) {
      if (mission.isHeader) {
        view.items.append({
          itemTag = mission.isCampaign ? "campaign_item" : "chapter_item_unlocked"
          id = mission.id
          itemText = this.misListType.getMissionNameText(mission)
          isCollapsable = (mission.isCampaign && this.canCollapseCampaigns) || this.canCollapseChapters
          isNeedOnHover = showConsoleButtons.value
        })
        continue
      }

      if (selIdx == -1)
        selIdx = idx

      if (!foundCurrent) {
        local isCurrent = false
        if (this.gm == GM_TRAINING
            || (this.gm == GM_CAMPAIGN && !selMisConfig))
          isCurrent = getTblValue("progress", mission, -1) == MIS_PROGRESS.UNLOCKED
        else
          isCurrent = selMisConfig == null || selMisConfig.id == mission.id

        if (isCurrent) {
          selIdx = idx
          foundCurrent = isCurrent
          if (this.gm == GM_CAMPAIGN && getTblValue("progress", mission, -1) == MIS_PROGRESS.UNLOCKED)
            hasVideoToPlay = true
        }
      }

      if (g_mislist_type.isUrlMission(mission)) {
        let medalIcon = this.misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite" : ""
        view.items.append({
          itemIcon = medalIcon
          id = mission.id
          itemText = this.misListType.getMissionNameText(mission)
          isNeedOnHover = showConsoleButtons.value
        })
        continue
      }

      local elemCssId = "mission_item_locked"
      local medalIcon = "#ui/gameuiskin#locked.svg"

      if (MODIFICATION_TUTORIAL_CHAPTERS.contains(mission.chapter)) {
        elemCssId = "mission_item_unlocked"
        medalIcon = ""
      }
      else if (this.gm == GM_CAMPAIGN || this.gm == GM_SINGLE_MISSION || this.gm == GM_TRAINING) {
        let progress = mission.progress
        if (progress == 0) {
          elemCssId = "mission_item_completed"
          medalIcon = "#ui/gameuiskin#mission_complete_arcade"
        }
        else if (progress == 1) {
          elemCssId = "mission_item_completed"
          medalIcon = "#ui/gameuiskin#mission_complete_realistic"
        }
        else if (progress == 2) {
          elemCssId = "mission_item_completed"
          medalIcon = "#ui/gameuiskin#mission_complete_simulator"
        }
        else if (progress == 3) {
          elemCssId = "mission_item_unlocked"
          medalIcon = ""
        }
      }
      else if (this.gm == GM_DOMINATION || this.gm == GM_SKIRMISH) {
        elemCssId = "mission_item_unlocked"
        medalIcon = this.misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite" : ""
      }
      else if (mission.isUnlocked) {
        elemCssId = "mission_item_unlocked"
        medalIcon = ""
      }

      view.items.append({
        itemTag = elemCssId
        itemIcon = medalIcon
        id = mission.id
        itemText = this.misListType.getMissionNameText(mission)
        isNeedOnHover = showConsoleButtons.value
      })
    }

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    for (local i = 0; i < listObj.childrenCount(); i++)
      listObj.getChild(i).setIntProp(this.listIdxPID, i)

    if (selIdx >= 0 && selIdx < listObj.childrenCount()) {
      let mission = this.missions[selIdx]
      if (hasVideoToPlay && this.gm == GM_CAMPAIGN)
        this.playChapterVideo(mission.chapter, true)

      listObj.setValue(selIdx)
    }
    else if (selIdx < 0)
      this.onItemSelect(listObj)

    this.createFilterDataArray()
    this.applyMissionFilter()
    this.updateCollapsedItems()
  }

  function createFilterDataArray() {
    let listObj = this.getObj("items_list")

    this.filterDataArray = []
    foreach (idx, mission in this.missions) {
      let locText = this.misListType.getMissionNameText(mission)
      let locString = utf8ToLower(locText)
      this.filterDataArray.append({
        locString = locString.replace("\t", "") 
        misObject = listObj.getChild(idx)
        mission = mission
        isHeader = mission.isHeader
        isCampaign = mission.isHeader && mission.isCampaign
        filterCheck = true
      })
    }
  }

  function playChapterVideo(chapterName, checkSeen = false) {
    let videoName = $"video/{chapterName}"
    if (checkSeen && was_video_seen(videoName))
      return

    if (!::check_package_and_ask_download("hc_pacific"))
      return

    this.guiScene.performDelayed(this, function(_obj) {
      play_movie(videoName, false, true, true)
      add_video_seen(videoName)
    })
  }

  function getSelectedMissionIndex(needCheckFocused = true) {
    let list = this.getObj("items_list")
    if (list != null && (!needCheckFocused || list.isHovered())) {
      let index = list.getValue()
      if (index >= 0 && index < list.childrenCount())
        return index
    }
    return -1
  }

  function getSelectedMission(needCheckFocused = true) {
    this.curMissionIdx = this.getSelectedMissionIndex(!this.isMouseMode && needCheckFocused)
    this.curMission = getTblValue(this.curMissionIdx, this.missions, null)
    return this.curMission
  }

  function onItemSelect(obj) {
    this.getSelectedMission(false)
    if (this.missionDescWeak) {
      local previewBlk = null
      if (this.gm == GM_DYNAMIC)
        previewBlk = getTblValue(this.curMissionIdx, get_mission_settings().dynlist)
      this.missionDescWeak.setMission(this.curMission, previewBlk)
    }
    this.updateButtons()

    if (checkObj(obj)) {
      let value = obj.getValue()
      if (value >= 0 && value < obj.childrenCount())
        obj.getChild(value).scrollToView()
    }
  }

  function onItemDblClick() {
    if (showConsoleButtons.value)
      return

    this.onStart()
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.value)
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(this.listIdxPID, -1)
    if (isHover == (this.hoveredIdx == idx))
      return
    this.hoveredIdx = isHover ? idx : -1
    this.updateMouseMode()
    this.updateButtons()
  }

  function onHoveredItemSelect(_obj) {
    if (this.hoveredIdx != -1)
      this.getObj("items_list")?.setValue(this.hoveredIdx)
  }

  function updateMouseMode() {
    this.isMouseMode = !showConsoleButtons.value || is_mouse_last_time_used()
  }

  function onEventSquadDataUpdated(_params) {
    if (this.gm == GM_SINGLE_MISSION)
      this.doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionChanged(_params) {
    this.doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionAdded(_params) {
    this.doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionLoaded(params) {
    if (params.mission != this.curMission.urlMission)
      return
    this.curMission.blk = params.mission.getMetaInfo()
    this.missionDescWeak?.setMission(this.curMission)
  }

  function getFavoritesSaveId() {
    return $"wnd/isOnlyFavoriteMissions/{this.misListType.id}"
  }

  function updateFavorites() {
    if (!this.misListType.canMarkFavorites()) {
      this.isOnlyFavorites = false
      return
    }

    this.isOnlyFavorites = loadLocalByAccount(this.getFavoritesSaveId(), false)
    let objValid = showObjById("favorite_missions_switch", true, this.scene)
    if (objValid)
      objValid.setValue(this.isOnlyFavorites)
  }

  function onOnlyFavoritesSwitch(obj) {
    let value = obj.getValue()
    if (value == this.isOnlyFavorites)
      return

    this.isOnlyFavorites = value
    saveLocalByAccount(this.getFavoritesSaveId(), this.isOnlyFavorites)
    this.applyMissionFilter()
    this.updateCollapsedItems()
  }

  function onFav() {
    if (!this.curMission || this.curMission.isHeader)
      return

    this.misListType.toggleFavorite(this.curMission)
    this.updateButtons()

    let listObj = this.getObj("items_list")
    if (this.curMissionIdx < 0 || this.curMissionIdx >= listObj.childrenCount())
      return

    let medalObj = listObj.getChild(this.curMissionIdx).findObject("medal_icon")
    if (medalObj)
      medalObj["background-image"] = this.misListType.isMissionFavorite(this.curMission) ? "#ui/gameuiskin#favorite" : ""
  }

  function goBack() {
    if (! this.filterText.len())
      this.saveCollapsedChapters()
    let gt = get_game_type()
    if ((this.gm == GM_DYNAMIC) && (gt & GT_COOPERATIVE) && isInSessionRoom.get()) {
      ::first_generation = false
      this.goForward(guiStartDynamicSummary)
      return
    }
    else if (isInSessionRoom.get()) {
      if (this.wndType != handlerType.MODAL) {
        this.goForward(guiStartMpLobby)
        return
      }
    }
    base.goBack()
  }

  function checkStartBlkMission(showMsgbox = false) {
    if (!("blk" in this.curMission))
      return true

    if (!this.curMission.isUnlocked && ("mustHaveUnit" in this.curMission)) {
      if (showMsgbox) {
        let unitNameLoc = colorize("activeTextColor", getUnitName(this.curMission.mustHaveUnit))
        let requirements = loc("conditions/char_unit_exist/single", { value = unitNameLoc })
        showInfoMsgBox($"{loc("charServer/needUnlock")}\n\n{requirements}")
      }
      return false
    }
    if ((this.gm == GM_SINGLE_MISSION) && (this.curMission.progress >= 4)) {
      if (showMsgbox) {
        let unlockId = $"{this.curMission.blk.chapter}/{this.curMission.blk.name}"
        let msg = $"{loc("charServer/needUnlock")}\n\n{getFullUnlockDescByName(unlockId, 1)}"
        showInfoMsgBox(msg, "in_demo_only_singlemission_unlock")
      }
      return false
    }
    if ((this.gm == GM_CAMPAIGN) && (this.curMission.progress >= 4)) {
      if (showMsgbox)
        showInfoMsgBox(loc("campaign/unlockPrevious"))
      return false
    }
    if ((this.gm != GM_CAMPAIGN) && !this.curMission.isUnlocked) {
      if (showMsgbox) {
        local msg = loc("ui/unavailable")
        if ("mustHaveUnit" in this.curMission)
          msg = format("%s\n%s", loc("unlocks/need_to_unlock"), getUnitName(this.curMission.mustHaveUnit))
        showInfoMsgBox(msg)
      }
      return false
    }
    return true
  }

  function onStart() {
    if (!this.curMission)
      return

    if (this.curMission.isHeader) {
      if ((this.curMission.isCampaign && this.canCollapseCampaigns) || this.canCollapseChapters)
        if (this.filterText.len() == 0)
          return this.collapse(this.curMission.id)
        else
          return

      if (this.gm != GM_CAMPAIGN)
        return

      if (this.curMission.isUnlocked)
        this.playChapterVideo(this.curMission.id)
      else
        showInfoMsgBox(loc("campaign/unlockPreviousChapter"))
      return
    }

    if (!::g_squad_utils.canJoinFlightMsgBox({
           isLeaderCanJoin = canPlayGamemodeBySquad(this.gm),
           showOfflineSquadMembersPopup = true
           maxSquadSize = getMaxPlayersForGamemode(this.gm)
         }))
      return

    if (! this.filterText.len())
      this.saveCollapsedChapters()

    if (getTblValue("blk", this.curMission) == null && g_mislist_type.isUrlMission(this.curMission)) {
      let misBlk = this.curMission.urlMission.getMetaInfo()
      if (misBlk)
        this.curMission.blk <- misBlk
      else {
        g_url_missions.loadBlk(this.curMission, Callback(this.onUrlMissionLoaded, this))
        return
      }
    }

    if (!this.checkStartBlkMission(true))
      return

    this.setMission()
  }

  function setMission() {
    set_mission_settings("postfix", null)
    currentCampaignId.set(this.curMission.chapter)
    currentCampaignMission.set(this.curMission.id)
    if (this.gm == GM_DYNAMIC)
      set_mission_settings("currentMissionIdx", this.curMissionIdx)

    this.openMissionOptions(this.curMission)
    if (this.gm == GM_TRAINING && ("blk" in this.curMission) && !MODIFICATION_TUTORIAL_CHAPTERS.contains(this.curMission.chapter))
      saveTutorialToCheckReward(this.curMission.blk)
  }

  function onUrlMissionLoaded(success, mission) {
    if (!success || !this.checkStartBlkMission(true))
      return

    this.curMission = mission
    this.curMission.blk <- this.curMission.urlMission.getMetaInfo()
    this.setMission()
  }

  function updateButtons() {
    let hoveredMission = this.isMouseMode ? null : this.missions?[this.hoveredIdx]
    let isCurItemInFocus = this.isMouseMode || (hoveredMission != null && hoveredMission == this.curMission)

    showObjById("btn_select_console", !isCurItemInFocus && hoveredMission != null, this.scene)

    let isHeader  = this.curMission?.isHeader ?? false
    let isMission = this.curMission != null && !isHeader

    let isShowFavoritesBtn = isCurItemInFocus && isMission && this.misListType.canMarkFavorites()
    let favObj = showObjById("btn_favorite", isShowFavoritesBtn, this.scene)
    if (checkObj(favObj) && isShowFavoritesBtn)
      favObj.setValue(this.misListType.isMissionFavorite(this.curMission) ?
        loc("mainmenu/btnFavoriteUnmark") : loc("mainmenu/btnFavorite"))

    local startText = ""
    if (isCurItemInFocus && (isMission || isHeader)) {
      if (isMission)
        startText = loc("multiplayer/btnStart")
      else if (this.filterText.len() == 0 && ((this.curMission?.isCampaign && this.canCollapseCampaigns) || (isHeader && this.canCollapseChapters)))
        startText = loc(this.collapsedCamp.contains(this.curMission.id) ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      else if (this.gm == GM_CAMPAIGN)
        startText = loc("mainmenu/btnWatchMovie")
    }

    let isShowStartBtn = startText != ""
    let startBtnObj = showObjById("btn_start", isShowStartBtn, this.scene)
    if (checkObj(startBtnObj) && isShowStartBtn) {
      let enabled = isHeader || (isMission && this.checkStartBlkMission())
      startBtnObj.inactiveColor = enabled ? "no" : "yes"
      setDoubleTextToButton(this.scene, "btn_start", startText)
    }

    local isShowSquadBtn = isCurItemInFocus && isMission &&
      isGameModeCoop(this.gm) && canPlayGamemodeBySquad(this.gm) && g_squad_manager.canInviteMember()
    if (this.gm == GM_SINGLE_MISSION)
      isShowSquadBtn = isShowSquadBtn
                       && (!("blk" in this.curMission)
                          || (this.curMission.blk.getBool("gt_cooperative", false) && !is_user_mission(this.curMission.blk)))
    showObjById("btn_inviteSquad", isShowSquadBtn, this.scene)

    showObjById("btn_refresh", this.misListType.canRefreshList, this.scene)
    showObjById("btn_refresh_console", this.misListType.canRefreshList && showConsoleButtons.value, this.scene)
    showObjById("btn_add_mission", this.misListType.canAddToList, this.scene)
    showObjById("btn_modify_mission", isCurItemInFocus && isMission && this.misListType.canModify(this.curMission), this.scene)
    showObjById("btn_delete_mission", isCurItemInFocus && isMission && this.misListType.canDelete(this.curMission), this.scene)

    let linkData = this.misListType.getInfoLinkData()
    let linkObj = showObjById("btn_user_missions_info_link", linkData != null, this.scene)
    if (linkObj && linkData) {
      linkObj.link = linkData.link
      linkObj.tooltip = linkData.tooltip
      linkObj.setValue(linkData.text)
    }

    if (this.gm == GM_CAMPAIGN)
      showObjById("btn_purchase_campaigns", hasFeature("OnlineShopPacks") && getNotPurchasedCampaigns().len() > 0, this.scene)
  }

  function getEmptyListMsg() {
    return g_squad_manager.isNotAloneOnline() ? loc("missions/noCoopMissions") : loc("missions/emptyList")
  }

  function updateCollapsedItems(selCamp = null) {
    let listObj = this.getObj("items_list")
    if (!listObj)
      return

    this.guiScene.setUpdatesEnabled(false, false)
    local collapsed = false
    let wasIdx = listObj.getValue()
    local selIdx = -1
    local hasAnyVisibleMissions = false
    let isFilteredMissions = this.filterText.len() > 0
    foreach (idx, m in this.missions) {
      local isVisible = true
      if ((m.isHeader && this.canCollapseChapters) || (m.isCampaign && this.canCollapseCampaigns)) {
        collapsed = !isFilteredMissions && isInArray(m.id, this.collapsedCamp)

        let obj = listObj.getChild(idx)
        if (obj) {
          obj.collapsed = collapsed ? "yes" : "no"
          let collapseBtnObj = obj.findObject($"btn_{obj.id}")
          if (checkObj(collapseBtnObj))
            collapseBtnObj.show(!isFilteredMissions)
        }

        if (selCamp && selCamp == m.id)
          selIdx = idx
      }
      else
        isVisible = !collapsed

      let obj = listObj.getChild(idx)
      if (!obj)
        continue

      let filterData = this.filterDataArray[idx]
      isVisible = isVisible && filterData.filterCheck
      if (isVisible && (selIdx < 0 || wasIdx == idx))
        selIdx = idx

      obj.enable(isVisible)
      obj.show(isVisible)
      hasAnyVisibleMissions = hasAnyVisibleMissions || isVisible
    }

    this.guiScene.setUpdatesEnabled(true, true)
    if (selIdx >= 0) {
      if (selIdx != wasIdx) {
        listObj.setValue(selIdx)
        this.onItemSelect(listObj)
      }
      else
        listObj.getChild(selIdx).scrollToView()
    }

    let listText = hasAnyVisibleMissions ? "" : this.getEmptyListMsg()
    this.scene.findObject("items_list_msg").setValue(listText)
  }

  function collapse(campId, forceOpen = false, shouldUpdate = true) {
    local hide = !forceOpen
    foreach (idx, camp in this.collapsedCamp)
      if (camp == campId) {
        this.collapsedCamp.remove(idx)
        hide = false
        break
      }
    if (hide)
      this.collapsedCamp.append(campId)

    if (!shouldUpdate)
      return

    this.updateCollapsedItems(campId)
    this.updateButtons()
  }

  function onCollapse(obj) {
    if (!obj)
      return
    let id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
      this.collapse(id.slice(4))
  }

  function openMissionOptions(mission) {
    let campaignName = currentCampaignId.get()

    this.missionName = currentCampaignMission.get()

    if (campaignName == null || this.missionName == null)
      return

    this.missionBlk = DataBlock()
    this.missionBlk.setFrom(mission.blk)

    let isUrlMission = g_mislist_type.isUrlMission(mission)
    if (isUrlMission)
      this.missionBlk.url = mission.urlMission.url

    let coopAvailable = isGameModeCoop(this.gm) && canPlayGamemodeBySquad(this.gm) && !is_user_mission(this.missionBlk)
    set_mission_settings("coop", this.missionBlk.getBool("gt_cooperative", false) && coopAvailable)

    this.missionBlk.setInt("_gameMode", this.gm)

    if ((isSessionLobbyCoop() && isInSessionRoom.get()) || isGameModeCoop(this.gm)) {
      set_mission_settings("players", 4)
      this.missionBlk.setInt("_players", 4)
      this.missionBlk.setInt("maxPlayers", 4)
      this.missionBlk.setBool("gt_use_lb", false)
      this.missionBlk.setBool("gt_use_replay", true)
      this.missionBlk.setBool("gt_use_stats", true)
      this.missionBlk.setBool("gt_sp_restart", false)
      this.missionBlk.setBool("isBotsAllowed", true)
      this.missionBlk.setBool("autoBalance", false)
    }

    if (isUrlMission)
      select_mission_full(this.missionBlk, mission.urlMission.fullMissionBlk)
    else
      select_mission(this.missionBlk, this.gm != GM_DOMINATION && this.gm != GM_SKIRMISH)

    let gt = get_game_type()
    let optionItems = ::get_briefing_options(this.gm, gt, this.missionBlk)
    let diffOption = u.search(optionItems, function(item) { return getTblValue(0, item) == USEROPT_DIFFICULTY })
    this.needCheckDiffAfterOptions = diffOption != null

    let cb = Callback(this.afterMissionOptionsApply, this)
    let misBlk = this.missionBlk
    this.createModalOptions(optionItems, function() {
      gui_handlers.Briefing.finalApply.call(this, misBlk) 
      cb()
    })
  }

  function afterMissionOptionsApply() {
    let diffCode = get_mission_settings().diff
    if (!::check_diff_pkg(diffCode))
      return

    this.checkedNewFlight(function() {
      if (this.needCheckDiffAfterOptions && get_gui_option(USEROPT_DIFFICULTY) == "custom")
        guiStartCdOptions(briefingOptionsApply, this)
      else
        briefingOptionsApply.call(this) 
    })
  }

  function createModalOptions(optionItems, applyFunc) {
    let params = this.getModalOptionsParam(optionItems, applyFunc)
    let handler = handlersManager.loadHandler(gui_handlers.GenericOptionsModal, params)

    if (!optionItems.len())
      handler.applyOptions()
  }

  function getModalOptionsParam(optionItems, applyFunc) {
    return {
      options = optionItems
      optionsConfig = {
        missionName = this.curMission?.id
        gm = this.gm
        forbiddenDifficulty = this.missionBlk?.forbiddenDifficulty
      }
      applyAtClose = false
      wndOptionsMode = ::get_options_mode(this.gm)
      owner = this
      applyFunc = applyFunc
    }
  }

  function showNav(show) {
    let obj = this.getObj("nav-help")
    if (obj) {
      obj.show(show)
      obj.enable(show)
    }
  }

  function onRefresh(_obj) {
    if (this.misListType.canRefreshList)
      this.updateWindow()
  }

  function initMisListTypeSwitcher() {
    if (!this.canSwitchMisListType)
      return
    let tabsObj = this.scene.findObject("chapter_top_list")
    if (!checkObj(tabsObj)) {
      this.canSwitchMisListType = false
      return
    }

    local curMisListType = g_mislist_type.BASE
    if (isInSessionRoom.get())
      curMisListType = getMisListType()
    else {
      let typeName = loadLocalByAccount("wnd/chosenMisListType", "")
      curMisListType = g_mislist_type.getTypeByName(typeName)
    }

    let typesList = []
    local selIdx = 0
    foreach (mlType in g_mislist_type.types)
      if (mlType.canCreate(this.gm)) {
        typesList.append(mlType)
        if (mlType == curMisListType)
          selIdx = typesList.len() - 1
      }

    if (typesList.len())
       this.misListType = typesList[selIdx]

    if (typesList.len() < 2) {
      this.canSwitchMisListType = false
      return
    }

    tabsObj.show(true)
    tabsObj.enable(true)
    this.fillHeaderTabs(tabsObj, typesList, selIdx)
    this.scene.findObject("chapter_name").show(false)
  }

  function fillHeaderTabs(tabsObj, typesList, selIdx) {
    let view = {
      tabs = []
    }
    foreach (idx, mlType in typesList)
      view.tabs.append({
        id = mlType.id
        tabName = mlType.getTabName()
        selected = idx == selIdx
        navImagesText = getNavigationImagesText(idx, typesList.len())
      })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
  }

  function onChapterSelect(obj) {
    if (!this.canSwitchMisListType)
      return

    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let typeName = obj.getChild(value).id
    this.misListType = g_mislist_type.getTypeByName(typeName)
    saveLocalByAccount("wnd/chosenMisListType", this.misListType.id)
    this.updateFavorites()
    this.updateWindow()
  }

  onFilterEditBoxActivate = @() null

  function onFilterEditBoxChangeValue(_) {
    clearTimer(this.applyFilterTimer)
    let filterEditBox = this.scene.findObject("filter_edit_box")
    let filterText = utf8ToLower(filterEditBox.getValue())
    if(filterText == "") {
      this.applyFilterImpl()
      return
    }

    let applyCallback = Callback(@() this.applyFilterImpl(), this)
    this.applyFilterTimer = setTimeout(0.8, @() applyCallback())
  }

  function applyFilterImpl() {
    this.applyMissionFilter()
    this.updateCollapsedItems()
    this.updateButtons()
  }

  function onFilterEditBoxCancel() {
    this.goBack()
  }

  function checkFilterData(filterData) {
    local res = !this.filterText.len()
      || utf8ToLower(filterData.locString).indexof(this.filterText) != null
      || utf8ToLower(filterData.mission.blk?.name ?? "").indexof(this.filterText) != null
    if (res && this.isOnlyFavorites)
      res = this.misListType.isMissionFavorite(filterData.mission)
    return res
  }

  function applyMissionFilter() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (!checkObj(filterEditBox))
      return

    this.filterText = utf8ToLower(filterEditBox.getValue())

    local showChapter = false
    local showCampaign = false
    for (local idx = this.filterDataArray.len() - 1; idx >= 0; --idx) {
      let filterData = this.filterDataArray[idx]
      
      local filterCheck = filterData.isHeader || this.checkFilterData(filterData)
      if (!filterData.isHeader) {
        if (filterCheck) {
          showChapter = true
          showCampaign = true
        }
      }
      else if (filterData.isCampaign) {
        filterCheck = showCampaign
        showCampaign = false
      }
      else {
        filterCheck = showChapter
        showChapter = false
      }

      filterData.filterCheck = filterCheck
    }
  }

  function onAddMission() {
    if (this.misListType.canAddToList)
      this.misListType.addToList()
  }

  function onModifyMission() {
    if (this.curMission && this.misListType.canModify(this.curMission))
      this.misListType.modifyMission(this.curMission)
  }

  function onDeleteMission() {
    if (this.curMission && this.misListType.canDelete(this.curMission))
      this.misListType.deleteMission(this.curMission)
  }

  function onBuyCampaign() {
    openBrowserForFirstFoundEntitlement(getNotPurchasedCampaigns())
  }

  function onEventProfileUpdated(p) {
    if (p.transactionType == EATT_UPDATE_ENTITLEMENTS)
      this.updateWindow()
  }
}

let SingleMissions = class (CampaignChapter) {
  sceneBlkName = "%gui/chapter.blk"
  sceneNavBlkName = "%gui/backSelectNavChapter.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  function initScreen() {
    this.scene.findObject("optionlist-container").mislist = "yes"
    base.initScreen()
  }
}

let SingleMissionsModal = class (SingleMissions) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/backSelectNavChapter.blk"
  owner = null

  filterMask = {}

  function initScreen() {
    let navObj = this.scene.findObject("nav-help")
    if (checkObj(navObj)) {
      let backBtn = navObj.findObject("btn_back")
      if (checkObj(backBtn))
        this.guiScene.destroyElement(backBtn)

      showObjById("btn_inviteSquad", true, this.scene)
    }

    let frameObj = this.scene.findObject("header_buttons")
    if (frameObj)
      this.guiScene.replaceContent(frameObj, "%gui/frameHeaderRefresh.blk", this)

    if (this.wndGameMode == GM_SKIRMISH || this.wndGameMode == GM_SINGLE_MISSION) {
      let listboxFilterHolder = this.scene.findObject("listbox_filter_holder")
      this.guiScene.replaceContent(listboxFilterHolder, "%gui/chapter_include_filter.blk", this)
    }

    base.initScreen()
  }

  function getFilterMask() {
    let mask = this.filterMask?[this.misListType.id]
    if (mask)
      return mask

    this.filterMask[this.misListType.id] <- { unit = -1, group = -1 }
    return this.filterMask[this.misListType.id]
  }

  function checkFilterData(filterData) {
    if (!base.checkFilterData(filterData))
      return false

    if (this.wndGameMode != GM_SKIRMISH || this.misListType == g_mislist_type.URL)
      return true

    let mask = this.getFilterMask()
    return (filterData.allowedUnitTypesMask & mask.unit) != 0
      && (filterData.group & mask.group) != 0
  }

  function createFilterDataArray() {
    base.createFilterDataArray()

    if (this.wndGameMode != GM_SKIRMISH)
      return

    let isFilterVisible = this.misListType != g_mislist_type.URL && this.filterDataArray.len() != 0
    let nestObj = showObjById("filter_nest", isFilterVisible, this.scene)

    if (!isFilterVisible)
      return

    foreach (v in this.filterDataArray) {
      if (v.isHeader)
        continue

      v.allowedUnitTypesMask <- getMissionAllowedUnittypesMask(v.mission.blk) || -1
      v.group <- getMissionGroup(v.mission)
    }

    openPopupFilter({
      scene = nestObj
      onChangeFn = this.onFilterCbChange.bindenv(this)
      filterTypesFn = this.getFiltersView.bindenv(this)
      popupAlign = "bottom"
      btnName = "RB"
    })
  }

  getAvailableMissionGroups = @() this.filterDataArray
    .reduce(@(acc, v) !v?.group || acc.contains(v.group) ? acc : acc.append(v.group), []) 
    .sort(@(a, b) a <=> b)

  getAvailableUnitTypes = @() unitTypes.types
    .filter(@(unitType) unitType.isAvailable())
    .sort(@(a, b) a.visualSortOrder <=> b.visualSortOrder)

  function getFiltersView() {
    let availableUnitTypes = this.getAvailableUnitTypes()
    let availableMissionGroups = this.getAvailableMissionGroups()
    let mask = this.getFilterMask()

    let unitColumnView = availableUnitTypes.map(@(unitType) {
      id    = $"unit_{unitType.bit}"
      image = unitType.testFlightIcon
      text  = unitType.getArmyLocName()
      value = !!(unitType.bit & mask.unit)
    })

    let groupColumnView = availableMissionGroups.map(@(g) {
      id    = $"group_{g}"
      text  = getMissionGroupName(g)
      value = !!(g & mask.group)
    })

    return [
      { checkbox = groupColumnView }
      { checkbox = unitColumnView }
    ]
  }

  function onFilterCbChange(objId, typeName, value) {
    let mask = this.getFilterMask()
    if (objId == RESET_ID)
      mask[typeName] = 0
    else if (objId == "group_favorite") {
      if (value == this.isOnlyFavorites)
        return

      this.isOnlyFavorites = value
      saveLocalByAccount(this.getFavoritesSaveId(), this.isOnlyFavorites)
    }
    else {
      let bit = objId.split("_")[1].tointeger()
      mask[typeName] = mask[typeName] ^ bit
    }
    this.applyMissionFilter()
    this.updateCollapsedItems()
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
  }

  function showWaitAnimation(isVisible) {
    if (isVisible)
      progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, { text = loc("wait/missionListLoading") })
    else
      progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
  }
}
let RemoteMissionModalHandler = class (CampaignChapter) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/empty.blk"

  mission = null

  function initScreen() {
    if (this.mission == null)
      return this.goBack()

    this.gm = get_game_mode()
    this.curMission = this.mission
    this.setMission()
  }

  function getModalOptionsParam(optionItems, applyFunc) {
    return {
      options = optionItems
      applyAtClose = false
      wndOptionsMode = ::get_options_mode(this.gm)
      owner = this
      applyFunc = applyFunc
      cancelFunc = Callback(function() {
                                isRemoteMissionVar.set(false)
                                this.goBack()
                              }, this)
    }
  }
}
gui_handlers.CampaignChapter <- CampaignChapter
gui_handlers.SingleMissions <- SingleMissions
gui_handlers.RemoteMissionModalHandler <- RemoteMissionModalHandler
gui_handlers.SingleMissionsModal <- SingleMissionsModal
