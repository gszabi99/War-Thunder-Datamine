from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { format } = require("string")
let progressMsg = require("%sqDagui/framework/progressMsg.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let { getMissionGroup, getMissionGroupName } = require("%scripts/missions/missionsFilterData.nut")
let { missionsListCampaignId } = require("%scripts/missions/getMissionsListCampaignId.nut")
let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { saveTutorialToCheckReward } = require("%scripts/tutorials/tutorialsData.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { isGameModeCoop } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let { getFullUnlockDescByName } = require("%scripts/unlocks/unlocksViewModule.nut")
let { get_gui_option } = require("guiOptions")

::current_campaign <- null
::current_campaign_name <- ""
::g_script_reloader.registerPersistentData("current_campaign_globals", getroottable(), ["current_campaign", "current_campaign_name"])
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"

::gui_handlers.CampaignChapter <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.BASE
  applyAtClose = false

  missions = []
  return_func = null
  curMission = null
  curMissionIdx = -1
  missionDescWeak = null

  listIdxPID = ::dagui_propid.add_name_id("listIdx")
  hoveredIdx = -1
  isMouseMode = true

  misListType = ::g_mislist_type.BASE
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

  function initScreen()
  {
    this.showWaitAnimation(true)

    this.gm = ::get_game_mode()
    this.loadCollapsedChapters()
    this.initCollapsingOptions()

    this.updateMouseMode()
    this.initMisListTypeSwitcher()
    this.updateFavorites()
    this.updateWindow()
    this.initDescHandler()
    ::move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  }

  function initDescHandler()
  {
    let descHandler = ::gui_handlers.MissionDescription.create(this.getObj("mission_desc"), this.curMission)
    this.registerSubHandler(descHandler)
    this.missionDescWeak = descHandler.weakref()
  }

  function initCollapsingOptions()
  {
    this.canCollapseCampaigns = this.gm != GM_SKIRMISH
    this.canCollapseChapters = this.gm == GM_SKIRMISH
  }

  function loadCollapsedChapters()
  {
    let collapsedList = ::load_local_account_settings(this.getCollapseListSaveId(), "")
    this.collapsedCamp = ::g_string.split(collapsedList, ";")
  }

  function saveCollapsedChapters()
  {
    ::save_local_account_settings(this.getCollapseListSaveId(), ::g_string.implode(this.collapsedCamp, ";"))
  }

  function getCollapseListSaveId()
  {
    return "mislist_collapsed_chapters/" + ::get_game_mode_name(this.gm)
  }

  function updateWindow()
  {
    local title = ""
    if (this.gm == GM_CAMPAIGN)
      title = loc("mainmenu/btnCampaign")
    else if (this.gm == GM_SINGLE_MISSION)
      title = (this.canSwitchMisListType || this.misListType != ::g_mislist_type.UGM)
              ? loc("mainmenu/btnSingleMission")
              : loc("mainmenu/btnUserMission")
    else if (this.gm == GM_SKIRMISH)
      title = loc("mainmenu/btnSkirmish")
    else
      title = loc("chapters/" + ::current_campaign_id)

    this.initMissionsList(title)
  }

  function initMissionsList(title)
  {
    let customChapterId = (this.gm == GM_DYNAMIC) ? ::current_campaign_id : missionsListCampaignId.value
    local customChapters = null
    if (!this.showAllCampaigns && (this.gm == GM_CAMPAIGN || this.gm == GM_SINGLE_MISSION))
      customChapters = ::current_campaign

    if (this.gm == GM_DYNAMIC)
    {
      let info = ::DataBlock()
      ::dynamic_get_visual(info)
      let l_file = info.getStr("layout","")
      let dynLayouts = ::get_dynamic_layouts()
      for (local i = 0; i < dynLayouts.len(); i++)
        if (dynLayouts[i].mis_file == l_file)
        {
          title = loc("dynamic/" + dynLayouts[i].name)
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

  function updateMissionsList(new_missions)
  {
    this.showWaitAnimation(false)

    this.missions = new_missions
    if (this.missions.len() <= 0 && !this.canSwitchMisListType && !this.misListType.canBeEmpty)
    {
      this.msgBox("no_missions", loc("missions/no_missions_msgbox"), [["ok"]], "ok")
      this.goBack()
      return
    }

    this.fillMissionsList()
  }

  function fillMissionsList()
  {
    let listObj = this.getObj("items_list")
    if (!listObj)
      return

    let selMisConfig = this.curMission || this.misListType.getCurMission()

    let view = { items = [] }
    local selIdx = -1
    local foundCurrent = false
    local hasVideoToPlay = false

    foreach(idx, mission in this.missions)
    {
      if (mission.isHeader)
      {
        view.items.append({
          itemTag = mission.isCampaign? "campaign_item" : "chapter_item_unlocked"
          id = mission.id
          itemText = this.misListType.getMissionNameText(mission)
          isCollapsable = (mission.isCampaign && this.canCollapseCampaigns) || this.canCollapseChapters
          isNeedOnHover = ::show_console_buttons
        })
        continue
      }

      if (selIdx == -1)
        selIdx = idx

      if (!foundCurrent)
      {
        local isCurrent = false
        if (this.gm ==GM_TRAINING
            || (this.gm == GM_CAMPAIGN && !selMisConfig))
          isCurrent = getTblValue("progress", mission, -1) == MIS_PROGRESS.UNLOCKED
        else
          isCurrent = selMisConfig == null || selMisConfig.id == mission.id

        if (isCurrent)
        {
          selIdx = idx
          foundCurrent = isCurrent
          if (this.gm == GM_CAMPAIGN && getTblValue("progress", mission, -1) == MIS_PROGRESS.UNLOCKED)
            hasVideoToPlay = true
        }
      }

      if (::g_mislist_type.isUrlMission(mission))
      {
        let medalIcon = this.misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite.png" : ""
        view.items.append({
          itemIcon = medalIcon
          id = mission.id
          itemText = this.misListType.getMissionNameText(mission)
          isNeedOnHover = ::show_console_buttons
        })
        continue
      }

      local elemCssId = "mission_item_locked"
      local medalIcon = "#ui/gameuiskin#locked.svg"
      if (this.gm == GM_CAMPAIGN || this.gm == GM_SINGLE_MISSION || this.gm == GM_TRAINING)
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
      else if (this.gm == GM_DOMINATION || this.gm == GM_SKIRMISH)
      {
        elemCssId = "mission_item_unlocked"
        medalIcon = this.misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite.png" : ""
      }
      else if (mission.isUnlocked)
      {
        elemCssId = "mission_item_unlocked"
        medalIcon = ""
      }

      view.items.append({
        itemTag = elemCssId
        itemIcon = medalIcon
        id = mission.id
        itemText = this.misListType.getMissionNameText(mission)
        isNeedOnHover = ::show_console_buttons
      })
    }

    let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    for (local i = 0; i < listObj.childrenCount(); i++)
      listObj.getChild(i).setIntProp(this.listIdxPID, i)

    if (selIdx >= 0 && selIdx < listObj.childrenCount())
    {
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

  function createFilterDataArray()
  {
    let listObj = this.getObj("items_list")

    this.filterDataArray = []
    foreach(idx, mission in this.missions)
    {
      let locText = this.misListType.getMissionNameText(mission)
      let locString = ::g_string.utf8ToLower(locText)
      this.filterDataArray.append({
        locString = ::stringReplace(locString, "\t", "") //for japan and china localizations
        misObject = listObj.getChild(idx)
        mission = mission
        isHeader = mission.isHeader
        isCampaign = mission.isHeader && mission.isCampaign
        filterCheck = true
      })
    }
  }

  function playChapterVideo(chapterName, checkSeen = false)
  {
    let videoName = "video/" + chapterName
    if (checkSeen && ::was_video_seen(videoName))
      return

    if (!::check_package_and_ask_download("hc_pacific"))
      return

    this.guiScene.performDelayed(this, (@(videoName) function(_obj) {
      if (!::is_system_ui_active())
      {
        ::play_movie(videoName, false, true, true)
        ::add_video_seen(videoName)
      }
    })(videoName))
  }

  function getSelectedMissionIndex(needCheckFocused = true)
  {
    let list = this.getObj("items_list")
    if (list != null && (!needCheckFocused || list.isHovered()))
    {
      let index = list.getValue()
      if (index >=0 && index < list.childrenCount())
        return index
    }
    return -1
  }

  function getSelectedMission(needCheckFocused = true)
  {
    this.curMissionIdx = this.getSelectedMissionIndex(!this.isMouseMode && needCheckFocused)
    this.curMission = getTblValue(this.curMissionIdx, this.missions, null)
    return this.curMission
  }

  function onItemSelect(obj)
  {
    this.getSelectedMission(false)
    if (this.missionDescWeak)
    {
      local previewBlk = null
      if (this.gm == GM_DYNAMIC)
        previewBlk = getTblValue(this.curMissionIdx, ::mission_settings.dynlist)
      this.missionDescWeak.setMission(this.curMission, previewBlk)
    }
    this.updateButtons()

    if (checkObj(obj))
    {
      let value = obj.getValue()
      if (value >= 0 && value < obj.childrenCount())
        obj.getChild(value).scrollToView()
    }
  }

  function onItemDblClick()
  {
    if (::show_console_buttons)
      return

    this.onStart()
  }

  function onItemHover(obj)
  {
    if (!::show_console_buttons)
      return
    let isHover = obj.isHovered()
    let idx = obj.getIntProp(this.listIdxPID, -1)
    if (isHover == (this.hoveredIdx == idx))
      return
    this.hoveredIdx = isHover ? idx : -1
    this.updateMouseMode()
    this.updateButtons()
  }

  function onHoveredItemSelect(_obj)
  {
    if (this.hoveredIdx != -1)
      this.getObj("items_list")?.setValue(this.hoveredIdx)
  }

  function updateMouseMode()
  {
    this.isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  }

  function onEventSquadDataUpdated(_params)
  {
    if (this.gm == GM_SINGLE_MISSION)
      this.doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionChanged(_params)
  {
    this.doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionAdded(_params)
  {
    this.doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionLoaded(params)
  {
    if (params.mission != this.curMission.urlMission)
      return
    this.curMission.blk = params.mission.getMetaInfo()
    this.missionDescWeak?.setMission(this.curMission)
  }

  function getFavoritesSaveId()
  {
    return "wnd/isOnlyFavoriteMissions/" + this.misListType.id
  }

  function updateFavorites()
  {
    if (!this.misListType.canMarkFavorites())
    {
      this.isOnlyFavorites = false
      return
    }

    this.isOnlyFavorites = ::loadLocalByAccount(this.getFavoritesSaveId(), false)
    let objValid = this.showSceneBtn("favorite_missions_switch", true)
    if (objValid)
      objValid.setValue(this.isOnlyFavorites)
  }

  function onOnlyFavoritesSwitch(obj)
  {
    let value = obj.getValue()
    if (value == this.isOnlyFavorites)
      return

    this.isOnlyFavorites = value
    ::saveLocalByAccount(this.getFavoritesSaveId(), this.isOnlyFavorites)
    this.applyMissionFilter()
    this.updateCollapsedItems()
  }

  function onFav()
  {
    if (!this.curMission || this.curMission.isHeader)
      return

    this.misListType.toggleFavorite(this.curMission)
    this.updateButtons()

    let listObj = this.getObj("items_list")
    if (this.curMissionIdx < 0 || this.curMissionIdx >= listObj.childrenCount())
      return

    let medalObj = listObj.getChild(this.curMissionIdx).findObject("medal_icon")
    if (medalObj)
      medalObj["background-image"] = this.misListType.isMissionFavorite(this.curMission) ? "#ui/gameuiskin#favorite.png" : ""
  }

  function goBack()
  {
    if( ! this.filterText.len())
      this.saveCollapsedChapters()
    let gt = ::get_game_type()
    if ((this.gm == GM_DYNAMIC) && (gt & GT_COOPERATIVE) && ::SessionLobby.isInRoom())
    {
      ::first_generation <- false
      this.goForward(::gui_start_dynamic_summary)
      return
    }
    else if (::SessionLobby.isInRoom())
    {
      if (this.wndType != handlerType.MODAL)
      {
        this.goForward(::gui_start_mp_lobby)
        return
      }
    }
    base.goBack()
  }

  function checkStartBlkMission(showMsgbox = false)
  {
    if (!("blk" in this.curMission))
      return true

    if (!this.curMission.isUnlocked && ("mustHaveUnit" in this.curMission))
    {
      if (showMsgbox)
      {
        let unitNameLoc = colorize("activeTextColor", ::getUnitName(this.curMission.mustHaveUnit))
        let requirements = loc("conditions/char_unit_exist/single", { value = unitNameLoc })
        ::showInfoMsgBox(loc("charServer/needUnlock") + "\n\n" + requirements)
      }
      return false
    }
    if ((this.gm == GM_SINGLE_MISSION) && (this.curMission.progress >= 4))
    {
      if (showMsgbox)
      {
        let unlockId = this.curMission.blk.chapter + "/" + this.curMission.blk.name
        let msg = loc("charServer/needUnlock") + "\n\n" + getFullUnlockDescByName(unlockId, 1)
        ::showInfoMsgBox(msg, "in_demo_only_singlemission_unlock")
      }
      return false
    }
    if ((this.gm == GM_CAMPAIGN) && (this.curMission.progress >= 4))
    {
      if (showMsgbox)
        ::showInfoMsgBox(loc("campaign/unlockPrevious"))
      return false
    }
    if ((this.gm != GM_CAMPAIGN) && !this.curMission.isUnlocked)
    {
      if (showMsgbox)
      {
        local msg = loc("ui/unavailable")
        if ("mustHaveUnit" in this.curMission)
          msg = format("%s\n%s", loc("unlocks/need_to_unlock"), ::getUnitName(this.curMission.mustHaveUnit))
        ::showInfoMsgBox(msg)
      }
      return false
    }
    return true
  }

  function onStart()
  {
    if (!this.curMission)
      return

    if (this.curMission.isHeader)
    {
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
        ::showInfoMsgBox( loc("campaign/unlockPreviousChapter"))
      return
    }

    if (!::g_squad_utils.canJoinFlightMsgBox({
           isLeaderCanJoin = ::can_play_gamemode_by_squad(this.gm),
           showOfflineSquadMembersPopup = true
           maxSquadSize = ::get_max_players_for_gamemode(this.gm)
         }))
      return

    if( ! this.filterText.len())
      this.saveCollapsedChapters()

    if (getTblValue("blk", this.curMission) == null && ::g_mislist_type.isUrlMission(this.curMission))
    {
      let misBlk = this.curMission.urlMission.getMetaInfo()
      if (misBlk)
        this.curMission.blk <- misBlk
      else
      {
        ::g_url_missions.loadBlk(this.curMission, Callback(this.onUrlMissionLoaded, this))
        return
      }
    }

    if (!this.checkStartBlkMission(true))
      return

    this.setMission()
  }

  function setMission()
  {
    ::mission_settings.postfix = null
    ::current_campaign_id = this.curMission.chapter
    ::current_campaign_mission = this.curMission.id
    if (this.gm == GM_DYNAMIC)
      ::mission_settings.currentMissionIdx <- this.curMissionIdx

    this.openMissionOptions(this.curMission)
    if (this.gm == GM_TRAINING && ("blk" in this.curMission))
      saveTutorialToCheckReward(this.curMission.blk)
  }

  function onUrlMissionLoaded(success, mission)
  {
    if (!success || !this.checkStartBlkMission(true))
      return

    this.curMission = mission
    this.curMission.blk <- this.curMission.urlMission.getMetaInfo()
    this.setMission()
  }

  function updateButtons()
  {
    let hoveredMission = this.isMouseMode ? null : this.missions?[this.hoveredIdx]
    let isCurItemInFocus = this.isMouseMode || (hoveredMission != null && hoveredMission == this.curMission)

    this.showSceneBtn("btn_select_console", !isCurItemInFocus && hoveredMission != null)

    let isHeader  = this.curMission?.isHeader ?? false
    let isMission = this.curMission != null && !isHeader

    let isShowFavoritesBtn = isCurItemInFocus && isMission && this.misListType.canMarkFavorites()
    let favObj = this.showSceneBtn("btn_favorite", isShowFavoritesBtn)
    if (checkObj(favObj) && isShowFavoritesBtn)
      favObj.setValue(this.misListType.isMissionFavorite(this.curMission) ?
        loc("mainmenu/btnFavoriteUnmark") : loc("mainmenu/btnFavorite"))

    local startText = ""
    if (isCurItemInFocus && (isMission || isHeader))
    {
      if (isMission)
        startText = loc("multiplayer/btnStart")
      else if (this.filterText.len() == 0 && ((this.curMission?.isCampaign && this.canCollapseCampaigns) || (isHeader && this.canCollapseChapters)))
        startText = loc(this.collapsedCamp.contains(this.curMission.id) ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      else if (this.gm == GM_CAMPAIGN)
        startText = loc("mainmenu/btnWatchMovie")
    }

    let isShowStartBtn = startText != ""
    let startBtnObj = this.showSceneBtn("btn_start", isShowStartBtn)
    if (checkObj(startBtnObj) && isShowStartBtn)
    {
      let enabled = isHeader || (isMission && this.checkStartBlkMission())
      startBtnObj.inactiveColor = enabled ? "no" : "yes"
      setDoubleTextToButton(this.scene, "btn_start", startText)
    }

    local isShowSquadBtn = isCurItemInFocus && isMission &&
      isGameModeCoop(this.gm) && ::can_play_gamemode_by_squad(this.gm) && ::g_squad_manager.canInviteMember()
    if (this.gm == GM_SINGLE_MISSION)
      isShowSquadBtn = isShowSquadBtn
                       && (!("blk" in this.curMission)
                          || (this.curMission.blk.getBool("gt_cooperative", false) && !::is_user_mission(this.curMission.blk)))
    this.showSceneBtn("btn_inviteSquad", isShowSquadBtn)

    this.showSceneBtn("btn_refresh", this.misListType.canRefreshList)
    this.showSceneBtn("btn_refresh_console", this.misListType.canRefreshList && ::show_console_buttons)
    this.showSceneBtn("btn_add_mission", this.misListType.canAddToList)
    this.showSceneBtn("btn_modify_mission", isCurItemInFocus && isMission && this.misListType.canModify(this.curMission))
    this.showSceneBtn("btn_delete_mission", isCurItemInFocus && isMission && this.misListType.canDelete(this.curMission))

    let linkData = this.misListType.getInfoLinkData()
    let linkObj = this.showSceneBtn("btn_user_missions_info_link", linkData != null)
    if (linkObj && linkData)
    {
      linkObj.link = linkData.link
      linkObj.tooltip = linkData.tooltip
      linkObj.setValue(linkData.text)
    }

    if (this.gm == GM_CAMPAIGN)
      this.showSceneBtn("btn_purchase_campaigns", hasFeature("OnlineShopPacks") && ::get_not_purchased_campaigns().len() > 0)
  }

  function getEmptyListMsg()
  {
    return ::g_squad_manager.isNotAloneOnline() ? loc("missions/noCoopMissions") : loc("missions/emptyList")
  }

  function updateCollapsedItems(selCamp=null)
  {
    let listObj = this.getObj("items_list")
    if (!listObj) return

    this.guiScene.setUpdatesEnabled(false, false)
    local collapsed = false
    let wasIdx = listObj.getValue()
    local selIdx = -1
    local hasAnyVisibleMissions = false
    let isFilteredMissions = this.filterText.len() > 0
    foreach(idx, m in this.missions)
    {
      local isVisible = true
      if ((m.isHeader && this.canCollapseChapters) || (m.isCampaign && this.canCollapseCampaigns))
      {
        collapsed = !isFilteredMissions && isInArray(m.id, this.collapsedCamp)

        let obj = listObj.getChild(idx)
        if (obj)
        {
          obj.collapsed = collapsed? "yes" : "no"
          let collapseBtnObj = obj.findObject("btn_" + obj.id)
          if (checkObj(collapseBtnObj))
            collapseBtnObj.show(!isFilteredMissions)
        }

        if (selCamp && selCamp==m.id)
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
    if (selIdx>=0)
    {
      if (selIdx != wasIdx)
      {
        listObj.setValue(selIdx)
        this.onItemSelect(listObj)
      } else
        listObj.getChild(selIdx).scrollToView()
    }

    let listText = hasAnyVisibleMissions ? "" : this.getEmptyListMsg()
    this.scene.findObject("items_list_msg").setValue(listText)
  }

  function collapse(campId, forceOpen = false, shouldUpdate = true)
  {
    local hide = !forceOpen
    foreach(idx, camp in this.collapsedCamp)
      if (camp == campId)
      {
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

  function onCollapse(obj)
  {
    if (!obj) return
    let id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
      this.collapse(id.slice(4))
  }

  function openMissionOptions(mission)
  {
    let campaignName = ::current_campaign_id

    this.missionName = ::current_campaign_mission

    if (campaignName == null || this.missionName == null)
      return

    this.missionBlk = ::DataBlock()
    this.missionBlk.setFrom(mission.blk)

    let isUrlMission = ::g_mislist_type.isUrlMission(mission)
    if (isUrlMission)
      this.missionBlk.url = mission.urlMission.url

    let coopAvailable = isGameModeCoop(this.gm) && ::can_play_gamemode_by_squad(this.gm) && !::is_user_mission(this.missionBlk)
    ::mission_settings.coop = this.missionBlk.getBool("gt_cooperative", false) && coopAvailable

    this.missionBlk.setInt("_gameMode", this.gm)

    if ((::SessionLobby.isCoop() && ::SessionLobby.isInRoom()) || isGameModeCoop(this.gm))
    {
      ::mission_settings.players = 4;
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
      ::select_mission_full(this.missionBlk, mission.urlMission.fullMissionBlk)
    else
      ::select_mission(this.missionBlk, this.gm != GM_DOMINATION && this.gm != GM_SKIRMISH)

    let gt = ::get_game_type()
    let optionItems = ::get_briefing_options(this.gm, gt, this.missionBlk)
    let diffOption = ::u.search(optionItems, function(item) { return getTblValue(0, item) == ::USEROPT_DIFFICULTY })
    this.needCheckDiffAfterOptions = diffOption != null

    let cb = Callback(this.afterMissionOptionsApply, this)
    this.createModalOptions(optionItems, (@(cb, missionBlk) function() {
      ::gui_handlers.Briefing.finalApply.call(this, missionBlk) //!!FIX ME: DIRTY HACK - called brifing function in modalOptions enviroment
      cb()
    })(cb, this.missionBlk))
  }

  function afterMissionOptionsApply()
  {
    let diffCode = ::mission_settings.diff
    if (!::check_diff_pkg(diffCode))
      return

    this.checkedNewFlight(function() {
      if (this.needCheckDiffAfterOptions && get_gui_option(::USEROPT_DIFFICULTY) == "custom")
        ::gui_start_cd_options(::briefing_options_apply, this)
      else
        ::briefing_options_apply.call(this) //!!FIX ME: DIRTY HACK
    })
  }

  function createModalOptions(optionItems, applyFunc)
  {
    let params = this.getModalOptionsParam(optionItems, applyFunc)
    let handler = ::handlersManager.loadHandler(::gui_handlers.GenericOptionsModal, params)

    if (!optionItems.len())
      handler.applyOptions()
  }

  function getModalOptionsParam(optionItems, applyFunc)
  {
    return {
      options = optionItems
      optionsConfig = { missionName = this.curMission && this.curMission.id }
      applyAtClose = false
      wndOptionsMode = ::get_options_mode(this.gm)
      owner = this
      applyFunc = applyFunc
    }
  }

  function showNav(show)
  {
    let obj = this.getObj("nav-help")
    if (obj)
    {
      obj.show(show)
      obj.enable(show)
    }
  }

  function onRefresh(_obj)
  {
    if (this.misListType.canRefreshList)
      this.updateWindow()
  }

  function initMisListTypeSwitcher()
  {
    if (!this.canSwitchMisListType)
      return
    let tabsObj = this.scene.findObject("chapter_top_list")
    if (!checkObj(tabsObj))
    {
      this.canSwitchMisListType = false
      return
    }

    local curMisListType = ::g_mislist_type.BASE
    if (::SessionLobby.isInRoom())
      curMisListType = ::SessionLobby.getMisListType()
    else
    {
      let typeName = ::loadLocalByAccount("wnd/chosenMisListType", "")
      curMisListType = ::g_mislist_type.getTypeByName(typeName)
    }

    let typesList = []
    local selIdx = 0
    foreach(mlType in ::g_mislist_type.types)
      if (mlType.canCreate(this.gm))
      {
        typesList.append(mlType)
        if (mlType == curMisListType)
          selIdx = typesList.len() - 1
      }

    if (typesList.len())
       this.misListType = typesList[selIdx]

    if (typesList.len() < 2)
    {
      this.canSwitchMisListType = false
      return
    }

    tabsObj.show(true)
    tabsObj.enable(true)
    this.fillHeaderTabs(tabsObj, typesList, selIdx)
    this.scene.findObject("chapter_name").show(false)
  }

  function fillHeaderTabs(tabsObj, typesList, selIdx)
  {
    let view = {
      tabs = []
    }
    foreach(idx, mlType in typesList)
      view.tabs.append({
        id = mlType.id
        tabName = mlType.getTabName()
        selected = idx == selIdx
        navImagesText = ::get_navigation_images_text(idx, typesList.len())
      })

    let data = ::handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
  }

  function onChapterSelect(obj)
  {
    if (!this.canSwitchMisListType)
      return

    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let typeName = obj.getChild(value).id
    this.misListType = ::g_mislist_type.getTypeByName(typeName)
    ::saveLocalByAccount("wnd/chosenMisListType", this.misListType.id)
    this.updateFavorites()
    this.updateWindow()
  }

  onFilterEditBoxActivate =@() null

  function onFilterEditBoxChangeValue()
  {
    this.applyMissionFilter()
    this.updateCollapsedItems()
    this.updateButtons()
  }

  function onFilterEditBoxCancel()
  {
    this.goBack()
  }

  function checkFilterData(filterData)
  {
    local res = !this.filterText.len() || filterData.locString.indexof(this.filterText) != null
    if (res && this.isOnlyFavorites)
      res = this.misListType.isMissionFavorite(filterData.mission)
    return res
  }

  function applyMissionFilter()
  {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (!checkObj(filterEditBox))
      return

    this.filterText = ::g_string.utf8ToLower(filterEditBox.getValue())

    local showChapter = false
    local showCampaign = false
    for (local idx = this.filterDataArray.len() - 1; idx >= 0; --idx)
    {
      let filterData = this.filterDataArray[idx]
      //need update headers by missions content
      local filterCheck = filterData.isHeader || this.checkFilterData(filterData)
      if (!filterData.isHeader)
      {
        if (filterCheck)
        {
          showChapter = true
          showCampaign = true
        }
      }
      else if (filterData.isCampaign)
      {
        filterCheck = showCampaign
        showCampaign = false
      }
      else
      {
        filterCheck = showChapter
        showChapter = false
      }

      filterData.filterCheck = filterCheck
    }
  }

  function onAddMission()
  {
    if (this.misListType.canAddToList)
      this.misListType.addToList()
  }

  function onModifyMission()
  {
    if (this.curMission && this.misListType.canModify(this.curMission))
      this.misListType.modifyMission(this.curMission)
  }

  function onDeleteMission()
  {
    if (this.curMission && this.misListType.canDelete(this.curMission))
      this.misListType.deleteMission(this.curMission)
  }

  function onBuyCampaign()
  {
    ::purchase_any_campaign()
  }

  function onEventProfileUpdated(p)
  {
    if (p.transactionType == EATT_UPDATE_ENTITLEMENTS)
      this.updateWindow()
  }
}

::gui_handlers.SingleMissions <- class extends ::gui_handlers.CampaignChapter
{
  sceneBlkName = "%gui/chapter.blk"
  sceneNavBlkName = "%gui/backSelectNavChapter.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  function initScreen()
  {
    this.scene.findObject("optionlist-container").mislist = "yes"
    base.initScreen()
  }
}

::gui_handlers.SingleMissionsModal <- class extends ::gui_handlers.SingleMissions
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/backSelectNavChapter.blk"
  owner = null

  filterMask = {}

  function initScreen()
  {
    let navObj = this.scene.findObject("nav-help")
    if(checkObj(navObj))
    {
      let backBtn = navObj.findObject("btn_back")
      if (checkObj(backBtn)) this.guiScene.destroyElement(backBtn)

      this.showSceneBtn("btn_inviteSquad", ::enable_coop_in_SingleMissions)
    }

    let frameObj = this.scene.findObject("header_buttons")
    if (frameObj)
      this.guiScene.replaceContent(frameObj, "%gui/frameHeaderRefresh.blk", this)

    if (this.wndGameMode == GM_SKIRMISH || this.wndGameMode == GM_SINGLE_MISSION)
    {
      let listboxFilterHolder = this.scene.findObject("listbox_filter_holder")
      this.guiScene.replaceContent(listboxFilterHolder, "%gui/chapter_include_filter.blk", this)
    }

    base.initScreen()
  }

  function getFilterMask()
  {
    let mask = this.filterMask?[this.misListType.id]
    if (mask)
      return mask

    this.filterMask[this.misListType.id] <- { unit = -1, group = -1 }
    return this.filterMask[this.misListType.id]
  }

  function checkFilterData(filterData)
  {
    if (!base.checkFilterData(filterData))
      return false

    if (this.wndGameMode != GM_SKIRMISH || this.misListType == ::g_mislist_type.URL)
      return true

    let mask = this.getFilterMask()
    return (filterData.allowedUnitTypesMask & mask.unit) != 0
      && (filterData.group & mask.group) != 0
  }

  function createFilterDataArray()
  {
    base.createFilterDataArray()

    if (this.wndGameMode != GM_SKIRMISH)
      return

    let isFilterVisible = this.misListType != ::g_mislist_type.URL && this.filterDataArray.len() != 0
    let nestObj = this.showSceneBtn("filter_nest", isFilterVisible)

    if (!isFilterVisible)
      return

    foreach (v in this.filterDataArray)
    {
      if (v.isHeader)
        continue

      v.allowedUnitTypesMask <- ::get_mission_allowed_unittypes_mask(v.mission.blk) || -1
      v.group <- getMissionGroup(v.mission)
    }

    openPopupFilter({
      scene = nestObj
      onChangeFn = this.onFilterCbChange.bindenv(this)
      filterTypes = this.getFiltersView()
      popupAlign = "bottom"
      btnName = "RB"
    })
  }

  getAvailableMissionGroups = @() this.filterDataArray
    .reduce(@(acc, v) !v?.group || acc.contains(v.group) ? acc : acc.append(v.group), []) // -unwanted-modification
    .sort(@(a, b) a <=> b)

  getAvailableUnitTypes = @() unitTypes.types
    .filter(@(u) u.isAvailable())
    .sort(@(a, b) a.visualSortOrder <=> b.visualSortOrder)

  function getFiltersView()
  {
    let availableUnitTypes = this.getAvailableUnitTypes()
    let availableMissionGroups = this.getAvailableMissionGroups()
    let mask = this.getFilterMask()

    let unitColumnView = availableUnitTypes.map(@(u) {
      id    = $"unit_{u.bit}"
      image = u.testFlightIcon
      text  = u.getArmyLocName()
      value = !!(u.bit & mask.unit)
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

  function onFilterCbChange(objId, typeName, value)
  {
    let mask = this.getFilterMask()
    if (objId == RESET_ID)
      mask[typeName] = 0
    else if (objId == "group_favorite")
    {
      if (value == this.isOnlyFavorites)
        return

      this.isOnlyFavorites = value
      ::saveLocalByAccount(this.getFavoritesSaveId(), this.isOnlyFavorites)
    }
    else
    {
      let bit = objId.split("_")[1].tointeger()
      mask[typeName] = mask[typeName] ^ bit
    }
    this.applyMissionFilter()
    this.updateCollapsedItems()
  }

  function afterModalDestroy()
  {
    this.restoreMainOptions()
  }

  function showWaitAnimation(isVisible)
  {
    if (isVisible)
      progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, {text = loc("wait/missionListLoading")})
    else
      progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
  }
}