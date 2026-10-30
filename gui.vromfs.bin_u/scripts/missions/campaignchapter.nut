import "%scripts/sqDagui/framework/progressMsg.nut" as progressMsg
import "%scripts/utils/getNavigationImagesText.nut" as getNavigationImagesText
import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/missions/misListType.nut" import getMislistTypeByName
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/missions/missionDescription.nut" import MissionDescription
from "%scripts/genericOptions.nut" import GenericOptionsModal
from "%scripts/briefing.nut" import getBriefingOptions, applyMissionOptions
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%scripts/popups/popupFilterWidget.nut" import RESET_ID, SELECT_ALL_ID, openPopupFilter
from "%scripts/missions/missionType.nut" import getMissionGroup, getMissionGroupName
from "%scripts/viewUtils/objectTextUpdate.nut" import setDoubleTextToButton
from "%scripts/tutorials/tutorialsData.nut" import saveTutorialToCheckReward
from "%scripts/viewUtils/hangarDof.nut" import needUseHangarDof
from "%scripts/matchingRooms/matchingGameModesUtils.nut" import isGameModeCoop
from "%scripts/unlocks/unlocksState.nut" import getFullUnlockDescByName
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/options/optionsExtNames.nut" import USEROPT_DIFFICULTY
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/matchingRooms/sessionLobbyState.nut" import isInSessionRoom, isSessionLobbyCoop
from "%scripts/missions/missionsUtils.nut" import getDynamicLayouts, getNotPurchasedCampaigns, getMissionAllowedUnittypesMask, getMaxPlayersForGamemode, canPlayGamemodeBySquad, isSquadGamemode
from "%scripts/onlineShop/onlineShopModel.nut" import openBrowserForFirstFoundEntitlement
from "%scripts/missions/startMissionsList.nut" import guiStartDynamicSummary, briefingOptionsApply, guiStartCdOptions
from "%scripts/missions/missionsStates.nut" import isRemoteMissionVar, currentCampaignId, currentCampaignMission, get_current_campaign, get_mission_settings, set_mission_settings, is_user_mission, isUrlMission
from "%scripts/matchingRooms/sessionLobbyManager.nut" import guiStartMpLobby
from "%scripts/matchingRooms/sessionLobbyInfo.nut" import getMisListType
from "%scripts/options/options.nut" import getOptionsMode
from "%scripts/clientState/contentPacks.nut" import checkDiffPkg, checkPackageAndAskDownloadByTimes
from "%scripts/squads/squadUtils.nut" import canJoinFlightMsgBox
from "%scripts/missions/missionProgress.nut" import MIS_PROGRESS
from "string" import format
from "guiOptions" import get_gui_option
from "dynamicMission" import dynamicGetVisual
from "guiMission" import select_mission, select_mission_full
from "mission" import get_game_mode, get_game_type
from "%sqstd/string.nut" import split, utf8ToLower
from "dagor.workcycle" import setTimeout, clearTimer
from "%globalScripts/gameTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import add_video_seen, was_video_seen, get_game_mode_name, is_mouse_last_time_used, play_movie
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/charActionConsts.nut" import *

let { g_url_missions } = require("%scripts/missions/urlMissionsList.nut")
let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { isFirstGeneration } = require("%scripts/missions/dynCampaingState.nut")

const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"
const ITEMS_LIST_EDGE = 1

let overScrollSizeYId = dagui_propid_add_name_id(":fix_content_size_y")

let MODIFICATION_TUTORIAL_CHAPTERS = ["tutorial_aircraft_modification", "tutorial_tank_modification"]

function updateMissionObj(obj, params) {
  let { id, itemType = "", itemText, isCollapsable = false, itemIcon = "" } = params
  obj.id = id
  obj.missionItemType = itemType
  obj.findObject("mission_item_text").setValue(itemText)
  obj.findObject("medal_icon")["background-image"] = itemIcon
  let collapseObj = showObjById("btn_mission_item_collapse", isCollapsable, obj)
  if (isCollapsable)
    collapseObj.missionId = id
}

function showWaitAnimation(isVisible) {
  if (isVisible)
    progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, { text = loc("wait/missionListLoading") })
  else
    progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
}

let CampaignChapter = class (BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  applyAtClose = false

  missions = []
  visibleMissions = null
  missionsPosY = null
  visibleMissionsIdxs = null
  curMission = null
  curMissionIdx = -1
  curVisibleMissionIdx = -1
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

  isUpdateMissionDesc = false
  cachedScrolledItemsCount = -1
  isIntoSelectionUpdate = false

  function initScreen() {
    this.gm = get_game_mode()

    let listPlace = this.scene.findObject("items_list_nest")
    this.guiScene.replaceContent(listPlace, "%gui/campChapterList.blk", this)

    this.loadCollapsedChapters()
    this.initCollapsingOptions()

    this.updateMouseMode()
    this.updateWindowTitle()
    this.initMisListTypeSwitcher()
    this.updateFavorites()
    this.initDescHandler()
    this.initMissionsList()
  }

  function initDescHandler() {
    let descHandler = MissionDescription.create(this.getObj("mission_desc"), this.curMission)
    if (descHandler == null)
      return
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

  function updateWindowTitle() {
    let obj = this.getObj("chapter_name")
    if (obj == null)
      return

    local title = ""
    if (this.gm == GM_CAMPAIGN)
      title = loc("mainmenu/btnCampaign")
    else if (this.gm == GM_SINGLE_MISSION)
      title = (this.canSwitchMisListType || this.misListType != g_mislist_type.UGM)
              ? loc("mainmenu/btnSingleMission")
              : loc("mainmenu/btnUserMission")
    else if (this.gm == GM_SKIRMISH)
      title = loc("mainmenu/btnSkirmish")
    else if (this.gm == GM_DYNAMIC) {
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
    else
      title = loc($"chapters/{currentCampaignId.get()}")

    obj.setValue(title)
  }

  function initMissionsList() {
    showWaitAnimation(true)
    let customChapterId = (this.gm == GM_DYNAMIC) ? currentCampaignId.get() : null
    local customChapters = null
    if (!this.showAllCampaigns && (this.gm == GM_CAMPAIGN || this.gm == GM_SINGLE_MISSION))
      customChapters = get_current_campaign()

    this.misListType.requestMissionsList(this.showAllCampaigns,
      Callback(this.updateMissionsList, this),
      customChapterId, customChapters)
  }

  function updateMissionsList(new_missions) {
    this.missions = new_missions
    if (this.missions.len() <= 0 && !this.canSwitchMisListType && !this.misListType.canBeEmpty) {
      showWaitAnimation(false)
      this.msgBox("no_missions", loc("missions/no_missions_msgbox"), [["ok"]], "ok")
      this.goBack()
      return
    }

    this.fillMissionsList()
  }

  function onScrollMissionsList(listObj) {
    let oldScrolledCount = this.cachedScrolledItemsCount
    this.updateScrolledItemsCount(listObj)
    this.updateListItemsPos(listObj)
    if (oldScrolledCount != this.cachedScrolledItemsCount)
      this.updateListItemsContent(listObj)
  }

  function getListSelectedIndex(listObj) {
    let scrolledItems = this.getScrolledItemsCount(listObj)
    let visibleSelectedIdx = this.curVisibleMissionIdx == -1
      ? -1
      : this.isIdxVisibleInList(this.curVisibleMissionIdx, scrolledItems, listObj.childrenCount())
        ? this.curVisibleMissionIdx - scrolledItems
        : -1

    return visibleSelectedIdx
  }

  function updateScrolledItemsCount(listObj) {
    if (listObj.childrenCount() <= 0)
      return
    let oneItem = listObj.getChild(0)
    let itemSize = oneItem.getSize()
    let scrollHeight = listObj.getScrollY()
    local count = (scrollHeight / itemSize[1]).tointeger()
    let visibleCount = this.missionsPosY.len()
    while (count < visibleCount && this.missionsPosY[count] > scrollHeight) {
      count--
    }
    this.cachedScrolledItemsCount = count
  }

  function getScrolledItemsCount(listObj) {
    if (this.cachedScrolledItemsCount == -1)
      this.updateScrolledItemsCount(listObj)
    return this.cachedScrolledItemsCount
  }

  function getItemsList() {
    return this.getObj("items_list")
  }

  function updateListItems(listObj) {
    this.updateListItemsPos(listObj)
    this.updateListItemsContent(listObj)
  }

  function updateListItemsPos(listObj) {
    let itemsCount = listObj.childrenCount()
    if (itemsCount == 0)
      return

    let scrolledItemsCount = this.getScrolledItemsCount(listObj)
    let posY = this.missionsPosY?[scrolledItemsCount] ?? 0
    listObj.getChild(0).pos = $"0, {posY}"
  }

  function updateListItemsContent(listObj) {
    let itemsCount = listObj.childrenCount()
    if (itemsCount == 0)
      return

    let scrolledItemsCount = this.getScrolledItemsCount(listObj)
    let listSelectedIndex = this.getListSelectedIndex(listObj)
    let isFilteredMissions = this.filterText.len() > 0

    for (local idx = scrolledItemsCount; idx < itemsCount + scrolledItemsCount; idx++) {
      let idxInList = idx - scrolledItemsCount
      let obj = listObj.getChild(idxInList)
      let mission = this.visibleMissions?[idx]
      if (mission == null) {
        obj.enable(false)
        obj.show(false)
        continue
      }

      obj.show(true)
      obj.enable(true)
      obj.setIntProp(this.listIdxPID, idxInList)
      obj.selected = (listSelectedIndex == idxInList) ? "yes" : null

      if (mission.isHeader) {
        updateMissionObj(obj, {
          id = mission.id
          itemType = mission.isCampaign ? "campaign" : "chapterUnlocked"
          itemText = mission.getNameText()
          isCollapsable = !isFilteredMissions &&
            ((mission.isCampaign && this.canCollapseCampaigns) || this.canCollapseChapters)
        })
        let collapsed = ((mission.isHeader && this.canCollapseChapters) || (mission.isCampaign && this.canCollapseCampaigns))
          && !isFilteredMissions && isInArray(mission.id, this.collapsedCamp)
        obj.collapsed = collapsed ? "yes" : "no"
        continue
      }

      if (isUrlMission(mission)) {
        let itemIcon = this.misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite" : ""
        updateMissionObj(obj, {
          itemIcon
          id = mission.id
          itemText = mission.getNameText()
        })
        continue
      }

      local itemType = "locked"
      local itemIcon = "#ui/gameuiskin#locked.svg"

      if (MODIFICATION_TUTORIAL_CHAPTERS.contains(mission.chapter)) {
        itemType = ""
        itemIcon = ""
      }
      else if (this.gm == GM_CAMPAIGN || this.gm == GM_SINGLE_MISSION || this.gm == GM_TRAINING) {
        let progress = mission.progress
        if (progress == 0) {
          itemType = "completed"
          itemIcon = "#ui/gameuiskin#mission_complete_arcade"
        }
        else if (progress == 1) {
          itemType = "completed"
          itemIcon = "#ui/gameuiskin#mission_complete_realistic"
        }
        else if (progress == 2) {
          itemType = "completed"
          itemIcon = "#ui/gameuiskin#mission_complete_simulator"
        }
        else if (progress == 3) {
          itemType = ""
          itemIcon = ""
        }
      }
      else if (this.gm == GM_DOMINATION || this.gm == GM_SKIRMISH) {
        itemType = ""
        itemIcon = this.misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite" : ""
      }
      else if (mission.isUnlocked) {
        itemType = ""
        itemIcon = ""
      }

      updateMissionObj(obj, {
        itemType
        itemIcon
        id = mission.id
        itemText = mission.getNameText()
      })
    }
  }

  function getPreferredMission() {
    let selMisConfig = this.curMission || this.misListType.getCurMission()
    local selIdx = -1
    local hasVideoToPlay = false
    local missionData = null
    let missionsCount = this.missions.len()
    for (local idx = 0; idx < missionsCount; idx++) {
      let mission = this.missions?[idx]
      if (mission == null || mission.isHeader)
        continue

      if (selIdx == -1)
        selIdx = idx

      local isCurrent = false
      if (this.gm == GM_TRAINING
          || (this.gm == GM_CAMPAIGN && !selMisConfig))
        isCurrent = (mission?.progress ?? -1) == MIS_PROGRESS.UNLOCKED
      else
        isCurrent = selMisConfig == null || selMisConfig.id == mission.id

      if (isCurrent) {
        selIdx = idx
        missionData = mission
        if (this.gm == GM_CAMPAIGN && (mission?.progress ?? -1) == MIS_PROGRESS.UNLOCKED)
          hasVideoToPlay = true
        break
      }
    }
    return {selIdx, hasVideoToPlay, mission = missionData}
  }

  function fillMissionsList() {
    let listObj = this.getItemsList()
    if (!listObj)
      return

    local itemsCount = listObj.childrenCount()
    let isFirstInit = itemsCount == 0
    if (isFirstInit) {
      this.guiScene.createMultiElementsByObject(listObj, "%gui/missions/missionBoxItem.blk",
        "mission_item", 1, this)
      itemsCount = 1
    }

    let child = listObj.getChild(0)
    let size = child.getSize()
    let clonesCount = (listObj.getSize()[1] / size[1]).tointeger() - itemsCount + 2
    if (clonesCount > 0)
      child.getClone(listObj, this, clonesCount)

    itemsCount = listObj.childrenCount()
    for (local i = 0; i < itemsCount; i++) {
      let itemObj = listObj.getChild(i)
      itemObj.position = i == 0 ? "relative" : "static"
    }

    this.createFilterDataArray()
    this.applyMissionFilter()

    let preferredMission = this.getPreferredMission()
    this.updateCollapsedItems(preferredMission.selIdx)

    this.updateListItems(listObj)
    showWaitAnimation(false)

    let scrolledCount = this.getScrolledItemsCount(listObj)
    let isVisibleInList = this.isIdxVisibleInList(this.curVisibleMissionIdx, scrolledCount, listObj.childrenCount())

    if (isFirstInit)
      move_mouse_on_child_by_value(listObj)

    if (isVisibleInList && preferredMission.hasVideoToPlay && this.gm == GM_CAMPAIGN) {
      if (this.visibleMissions?[this.curVisibleMissionIdx] == preferredMission.mission) 
        this.playChapterVideo(preferredMission.mission.chapter, true)
    }
  }

  function createFilterDataArray() {
    this.filterDataArray = []
    foreach (mission in this.missions) {
      let locText = mission.getNameText()
      let locString = utf8ToLower(locText)
      this.filterDataArray.append({
        locString = locString.replace("\t", "") 
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

    let playVideo = @() this.guiScene.performDelayed(this, function(_obj) {
      play_movie(videoName, false, true, true)
      add_video_seen(videoName)
    })

    checkPackageAndAskDownloadByTimes("hc_pacific", playVideo, this, null, true)
  }

  function onListWrapUp(obj) {
    let scrolledCount = this.getScrolledItemsCount(obj)
    if (scrolledCount > 0) {
      this.scrollToMissionTop(scrolledCount - 1, obj)
      return
    }
    set_dirpad_event_processed(false)
  }

  function onListWrapDown(obj) {
    let lastMissionInList = this.getScrolledItemsCount(obj) + obj.childrenCount()
    if (lastMissionInList < this.visibleMissions.len() - 1) {
      let itemHeight = obj.getChild(0)?.getSize()[1] ?? 0
      this.setListScrollY(obj, obj.getScrollY() + itemHeight)
      return
    }
    set_dirpad_event_processed(false)
  }

  function isIdxVisibleInList(idx, scrolledCount, listItemsCount) {
    return ((idx >= scrolledCount) && (idx < scrolledCount + listItemsCount))
  }

  function checkScrollEdgeItems(listObj, visibleMissionIndex) {
    let scrolledCount = this.getScrolledItemsCount(listObj )
    let childIndex = visibleMissionIndex - scrolledCount
    let listItemsCount = listObj.childrenCount()
    if (childIndex < 0 || childIndex >= listItemsCount )
      return

    let misObj = listObj.getChild(childIndex)
    if (childIndex >= listItemsCount - ITEMS_LIST_EDGE) {
      let mBottomEdge = misObj.getSize()[1] + misObj.getPos()[1]
      if (mBottomEdge > listObj.getSize()[1] + listObj.getPos()[1])
        this.scrollToMissionBottom(visibleMissionIndex, listObj)
    } else if (childIndex < ITEMS_LIST_EDGE) {
      let mTopEdge = misObj.getPos()[1]
      if (mTopEdge < listObj.getPos()[1])
        this.scrollToMissionTop(visibleMissionIndex, listObj)
    }
  }

  function setListScrollY(listObj, val) {
    this.cachedScrolledItemsCount = - 1
    listObj.scrollToY(val)
  }

  function scrollToMissionTop(visibleMissionIdx, listObj) {
    if (visibleMissionIdx < 0)
      return
    this.setListScrollY(listObj, this.missionsPosY?[visibleMissionIdx] ?? 0)
  }

  function scrollToMissionBottom(visibleMissionIdx, listObj) {
    if (visibleMissionIdx < 0)
      return
    let itemHeight = listObj.getChild(0).getSize()[1]
    visibleMissionIdx = visibleMissionIdx < this.missionsPosY.len()
      ? visibleMissionIdx
      : this.missionsPosY.len() - 1
    this.setListScrollY(listObj,
      this.missionsPosY[visibleMissionIdx] + itemHeight - listObj.getSize()[1])
  }

  function scrollToMission(visibleMissionIdx, listObj) {
    if (visibleMissionIdx < 0)
      return
    let scrolledCount = this.getScrolledItemsCount(listObj)
    let isVisibleInList = this.isIdxVisibleInList(visibleMissionIdx, scrolledCount, listObj.childrenCount())
    if (isVisibleInList) {
      this.checkScrollEdgeItems(listObj, visibleMissionIdx)
      return
    }
    this.setListScrollY(listObj, this.missionsPosY?[visibleMissionIdx] ?? 0)
  }

  function selectMission(mission, listObj) {
    let scrolledCount = this.getScrolledItemsCount(listObj)

    let oldVisibleIdx = this.curVisibleMissionIdx
    let oldMissionTextId = this.curMission?.id
    this.curVisibleMissionIdx = this.visibleMissions.indexof(mission) ?? -1
    this.curMissionIdx = this.curVisibleMissionIdx >= 0
      ? this.visibleMissionsIdxs[this.curVisibleMissionIdx]
      : -1
    this.curMission = this.curVisibleMissionIdx >= 0
      ? mission
      : null

    let listItemsCount = listObj.childrenCount()
    let isVisibleInList = this.isIdxVisibleInList(this.curVisibleMissionIdx, scrolledCount, listItemsCount)
    let isPrevSelectedInList = this.isIdxVisibleInList(oldVisibleIdx, scrolledCount, listItemsCount)
    if (isPrevSelectedInList) {
      let obj = listObj.getChild(oldVisibleIdx - scrolledCount)
      obj.selected = null
    }

    if (isVisibleInList) {
      let childIndex = this.curVisibleMissionIdx - scrolledCount
      this.isIntoSelectionUpdate = true
      listObj.setValue(childIndex)
      this.isIntoSelectionUpdate = false
    }

    if (this.curMission?.id == oldMissionTextId)
      return

    if (this.missionDescWeak) {
      this.isUpdateMissionDesc = true
      local previewBlk = null
      if (this.gm == GM_DYNAMIC)
        previewBlk = get_mission_settings().dynlist?[this.curMissionIdx]
      this.missionDescWeak.setMission(this.curMission, previewBlk)
      this.isUpdateMissionDesc = false
    }
    this.updateButtons(listObj)
  }

  function selectMissionByListIdx(listIdx, listObj) {
    let scrolledCount = this.getScrolledItemsCount(listObj)
    let mission = this.visibleMissions?[scrolledCount + listIdx]
    this.selectMission(mission, listObj)
  }

  function onItemSelect(listObj) {
    if (this.isUpdateMissionDesc || this.isIntoSelectionUpdate)
      return
    this.selectMissionByListIdx(listObj.getValue(), listObj)
  }

  function onItemDblClick() {
    if (showConsoleButtons.get()) {
      let listObj = this.getItemsList()
      if (listObj)
        this.onItemSelect(listObj)
      return
    }
    this.onStart()
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.get())
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
      this.getItemsList()?.setValue(this.hoveredIdx)
  }

  function updateMouseMode() {
    this.isMouseMode = !showConsoleButtons.get() || is_mouse_last_time_used()
  }

  function onEventSquadDataUpdated(_params) {
    if (this.gm == GM_SINGLE_MISSION)
      this.doWhenActiveOnce("initMissionsList")
  }

  function onEventUrlMissionChanged(_params) {
    this.doWhenActiveOnce("initMissionsList")
  }

  function onEventUrlMissionAdded(_params) {
    this.doWhenActiveOnce("initMissionsList")
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
    this.applyFilterImpl()
  }

  function onFav() {
    if (!this.curMission || this.curMission.isHeader)
      return

    this.misListType.toggleFavorite(this.curMission)
    let listObj = this.getItemsList()
    this.updateButtons(listObj)
    let listSelectedIndex = this.getListSelectedIndex(listObj)
    if (listSelectedIndex < 0 || listSelectedIndex >= listObj.childrenCount())
      return

    let medalObj = listObj.getChild(listSelectedIndex).findObject("medal_icon")
    if (medalObj)
      medalObj["background-image"] = this.misListType.isMissionFavorite(this.curMission) ? "#ui/gameuiskin#favorite" : ""
  }

  function goBack() {
    if (! this.filterText.len())
      this.saveCollapsedChapters()
    let gt = get_game_type()
    if ((this.gm == GM_DYNAMIC) && (gt & GT_COOPERATIVE) && isInSessionRoom.get()) {
      isFirstGeneration.value = false
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

    if (!canJoinFlightMsgBox({
           isLeaderCanJoin = canPlayGamemodeBySquad(this.gm)
           checkSquadReady = !isSquadGamemode(this.gm) 
           showOfflineSquadMembersPopup = true
           maxSquadSize = getMaxPlayersForGamemode(this.gm)
         }))
      return

    if (! this.filterText.len())
      this.saveCollapsedChapters()

    if (this.curMission?.blk == null && isUrlMission(this.curMission)) {
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

  function updateButtons(listObj = null) {
    local hoveredMission = null
    if (this.hoveredIdx >= 0 && !this.isMouseMode) {
      listObj = listObj ?? this.getItemsList()
      let scrolledItemsCount = this.getScrolledItemsCount(listObj)
      hoveredMission = this.visibleMissions?[scrolledItemsCount + this.hoveredIdx]
    }
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
    showObjById("btn_refresh_console", this.misListType.canRefreshList && showConsoleButtons.get(), this.scene)
    showObjById("btn_add_mission", this.misListType.canAddToList, this.scene)
    showObjById("btn_modify_mission", isCurItemInFocus && isMission && this.misListType.canModify(this.curMission), this.scene)
    showObjById("btn_delete_mission", isCurItemInFocus && isMission && this.misListType.canDelete(this.curMission), this.scene)

    let linkData = this.misListType.getInfoLinkData()
    let linkObj = showObjById("btn_user_missions_info_link", linkData != null, this.scene)
    if (linkObj && linkData) {
      linkObj.link = linkData.link
      linkObj.tooltip = linkData.tooltip
      linkObj.setValue(linkData.text)
      linkObj.forceExternal = linkData.forceExternal ? "yes" : "no"
    }

    if (this.gm == GM_CAMPAIGN)
      showObjById("btn_purchase_campaigns", hasFeature("OnlineShopPacks") && getNotPurchasedCampaigns().len() > 0, this.scene)
  }

  function getEmptyListMsg() {
    return g_squad_manager.isNotAloneOnline() ? loc("missions/noCoopMissions") : loc("missions/emptyList")
  }

  function updateCollapsedItems(preferredIdx = -1) {
    local collapsed = false
    let wasIdx = preferredIdx >= 0 ? preferredIdx : this.curMissionIdx
    let isFilteredMissions = this.filterText.len() > 0
    local currentChapterIdx = -1

    this.visibleMissions = []
    this.missionsPosY = []
    this.visibleMissionsIdxs = []
    this.cachedScrolledItemsCount = -1

    let listObj = this.getItemsList()
    if (listObj.childrenCount() == 0)
      return
    let misItem = listObj.getChild(0)
    let misHeight = misItem.getSize()[1]
    local firstVisibleMissionIdx = -1
    local visibleChapterIdx = -1
    local visibleSelIdx = -1
    local visibleMissionsCount = 0

    let mainGuiScene = get_main_gui_scene()
    let campaignTopMargin = to_pixels(mainGuiScene.getConstantValue("campaignMarginTop"))

    local posY = 0
    foreach (idx, m in this.missions) {
      local isVisible = true
      if ((m.isHeader && this.canCollapseChapters) || (m.isCampaign && this.canCollapseCampaigns)) {
        collapsed = !isFilteredMissions && isInArray(m.id, this.collapsedCamp)
        currentChapterIdx = idx
        visibleChapterIdx = visibleMissionsCount
      }
      else
        isVisible = !collapsed

      let filterData = this.filterDataArray[idx]
      isVisible = isVisible && filterData.filterCheck

      if (!isVisible && (idx == wasIdx) && (visibleChapterIdx >= 0))
        visibleSelIdx = visibleChapterIdx

      if (isVisible) {
        this.missionsPosY.append(posY)
        this.visibleMissionsIdxs.append(idx)
        this.visibleMissions.append(m)

        if (firstVisibleMissionIdx < 0 && currentChapterIdx != idx)
          firstVisibleMissionIdx = visibleMissionsCount

        if (m.isCampaign)
          posY += campaignTopMargin
        posY += misHeight

        if (visibleSelIdx < 0 || wasIdx == idx)
          visibleSelIdx = visibleMissionsCount

        visibleMissionsCount++
      }
    }

    let listText = visibleMissionsCount > 0 ? "" : this.getEmptyListMsg()
    this.scene.findObject("items_list_msg").setValue(listText)
    this.updateListSize(listObj, posY)
    visibleSelIdx = (visibleSelIdx >= 0 && visibleSelIdx < visibleMissionsCount)
      ? visibleSelIdx
      : firstVisibleMissionIdx
    if (preferredIdx >= 0 && visibleSelIdx >= 0)
      this.scrollToMission(visibleSelIdx, listObj)
    this.selectMission(this.visibleMissions?[visibleSelIdx], listObj)
  }

  function updateListSize(listObj, sizeY) {
    listObj.setIntProp(overScrollSizeYId, sizeY)
    listObj.markSceneChanged()
    this.guiScene.applyPendingChanges(false)
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

    this.updateCollapsedItems()
    let listObj = this.getItemsList()
    this.updateButtons(listObj)
    this.updateListItems(listObj)
  }

  function onCollapse(obj) {
    if (!obj)
      return
    let id = obj?.missionId ?? ""
    if (id != "")
      this.collapse(id)
  }

  function openMissionOptions(mission) {
    let campaignName = currentCampaignId.get()

    this.missionName = currentCampaignMission.get()

    if (campaignName == null || this.missionName == null)
      return

    this.missionBlk = DataBlock()
    this.missionBlk.setFrom(mission.blk)

    let isMissionByUrl = isUrlMission(mission)
    if (isMissionByUrl)
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

    if (isMissionByUrl)
      select_mission_full(this.missionBlk, mission.urlMission.fullMissionBlk)
    else
      select_mission(this.missionBlk, this.gm != GM_DOMINATION && this.gm != GM_SKIRMISH)

    let gt = get_game_type()
    let optionItems = getBriefingOptions(this.gm, gt, this.missionBlk)
    let diffOption = u.search(optionItems, function(item) { return item?[0] == USEROPT_DIFFICULTY })
    this.needCheckDiffAfterOptions = diffOption != null

    let cb = Callback(this.afterMissionOptionsApply, this)
    let misBlk = this.missionBlk
    this.createModalOptions(optionItems, function(optionsHandler) {
      applyMissionOptions(optionsHandler, misBlk)
      cb()
    })
  }

  function afterMissionOptionsApply() {
    let diffCode = get_mission_settings().diff
    if (!checkDiffPkg(diffCode))
      return

    this.checkedNewFlight(function() {
      if (this.needCheckDiffAfterOptions && get_gui_option(USEROPT_DIFFICULTY) == "custom")
        guiStartCdOptions(briefingOptionsApply, this)
      else
        briefingOptionsApply()
    })
  }

  function createModalOptions(optionItems, applyFunc) {
    let params = this.getModalOptionsParam(optionItems, applyFunc)
    let handler = handlersManager.loadHandler(GenericOptionsModal, params)

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
      wndOptionsMode = getOptionsMode(this.gm)
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
      this.initMissionsList()
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
      curMisListType = getMislistTypeByName(typeName)
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
    this.misListType = getMislistTypeByName(typeName)
    saveLocalByAccount("wnd/chosenMisListType", this.misListType.id)
    this.updateFavorites()
    this.initMissionsList()
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
    let listObj = this.getItemsList()
    this.scrollToMission(this.curVisibleMissionIdx, listObj)
    this.updateListItems(listObj)
    this.updateButtons(listObj)
  }

  function onFilterEditBoxCancel() {
    this.goBack()
  }

  function checkFilterData(filterData) {
    local res = !this.filterText.len()
      || filterData.locString.indexof(this.filterText) != null
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
      this.initMissionsList()
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

      let favFilterBtn = navObj.findObject("favorite_missions_switch")
      if (favFilterBtn?.isValid())
        favFilterBtn["margin-left"] = "1@buttonMargin"
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

      let allowedMask = getMissionAllowedUnittypesMask(v.mission.blk)
      v.allowedUnitTypesMask <- allowedMask == 0 ? -1 : allowedMask
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
    .sort()

  getAvailableUnitTypes = @() unitTypes.types
    .filter(@(unitType) unitType.isAvailable())
    .sortby(@(a) a.visualSortOrder)

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
    else if (objId == SELECT_ALL_ID)
      mask[typeName] = -1
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
    this.applyFilterImpl()
  }

  function afterModalDestroy() {
    this.restoreMainOptions()
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
      wndOptionsMode = getOptionsMode(this.gm)
      owner = this
      applyFunc = applyFunc
      cancelFunc = Callback(function() {
                                isRemoteMissionVar.set(false)
                                this.goBack()
                              }, this)
    }
  }
}
register_gui_handler("CampaignChapter", CampaignChapter)
register_gui_handler("SingleMissions", SingleMissions)
register_gui_handler("RemoteMissionModalHandler", RemoteMissionModalHandler)
register_gui_handler("SingleMissionsModal", SingleMissionsModal)

return freeze({ CampaignChapter })
