local time = require("scripts/time.nut")
local replayMetadata = require("scripts/replays/replayMetadata.nut")

const REPLAY_SESSION_ID_MIN_LENGHT = 16

::autosave_replay_max_count <- 100
::autosave_replay_prefix <- "#"

::current_replay <- ""
::current_replay_author <- null
::back_from_replays <- null

::g_script_reloader.registerPersistentData("ReplayScreenGlobals", ::getroottable(), ["current_replay", "current_replay_author"])

::gui_start_replays <- function gui_start_replays()
{
  ::gui_start_modal_wnd(::gui_handlers.ReplayScreen)
}

::gui_start_menuReplays <- function gui_start_menuReplays()
{
  ::gui_start_mainmenu()
  ::gui_start_replays()
}

::gui_start_worldWar <- function gui_start_worldWar()
{
  ::g_world_war.openMainWnd()
}

::gui_start_replay_battle <- function gui_start_replay_battle(sessionId, backFunc)
{
  ::back_from_replays = function() {
    ::SessionLobby.resetPlayersInfo()
    backFunc()
  }
  ::req_unlock_by_client("view_replay", false)
  ::current_replay = ::get_replay_url_by_session_id(sessionId)
  ::current_replay_author = null
  ::on_view_replay(::current_replay)
}

::get_replay_url_by_session_id <- function get_replay_url_by_session_id(sessionId)
{
  local sessionIdText = ::format("%0" + REPLAY_SESSION_ID_MIN_LENGHT + "s", sessionId.tostring())
  return ::loc("url/server_wt_game_replay", {sessionId = sessionIdText})
}

::gui_modal_rename_replay <- function gui_modal_rename_replay(base_name, base_path, func_owner, after_rename_func, after_func = null)
{
  ::gui_start_modal_wnd(::gui_handlers.RenameReplayHandler, {
                                                              baseName = base_name
                                                              basePath = base_path
                                                              funcOwner = func_owner
                                                              afterRenameFunc = after_rename_func
                                                              afterFunc = after_func
                                                            })
}

::gui_modal_name_and_save_replay <- function gui_modal_name_and_save_replay(func_owner, after_func)
{
  local baseName = ::get_new_replay_filename();
  local basePath = ::get_replays_dir() + "\\" + baseName;
  ::gui_modal_rename_replay(baseName, basePath, func_owner, null, after_func);
}

::autosave_replay <- function autosave_replay()
{
  if (::is_replay_saved())
    return;
  if (!::get_option_autosave_replays())
    return;
  if (::get_game_mode() == ::GM_BENCHMARK)
    return;

  local replays = ::get_replays_list();
  local autosaveCount = 0;
  for (local i = 0; i < replays.len(); i++)
  {
    if (replays[i].name.slice(0,1) == ::autosave_replay_prefix)
      autosaveCount++;
  }
  local toDelete = autosaveCount - (::autosave_replay_max_count - 1);
  for (local d = 0; d < toDelete; d++)
  {
    local indexToDelete = -1;
    for (local i = 0; i < replays.len(); i++)
    {
      if (replays[i].name.slice(0,1) != ::autosave_replay_prefix)
        continue;

      if (replays[i]?.corrupted || replays[i]?.isVersionMismatch)
      {
        indexToDelete = i;
        break;
      }
    }
    if (indexToDelete < 0)
    {
      //sort by time
      local oldestDate = -1
      for (local i = 0; i < replays.len(); i++)
      {
        if (replays[i].name.slice(0,1) != ::autosave_replay_prefix)
          continue;

        local startTime = replays[i]?.startTime ?? -1
        if (oldestDate < 0 || startTime < oldestDate)
        {
          oldestDate = startTime
          indexToDelete = i;
        }
      }
    }

    if (indexToDelete >= 0)
    {
      ::on_del_replay(replays[indexToDelete].path);
      replays.remove(indexToDelete);
    }
  }

  local name = ::autosave_replay_prefix + ::get_new_replay_filename();
  ::on_save_replay(name); //ignore errors
}

class ::gui_handlers.ReplayScreen extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chapterModal.blk"
  sceneNavBlkName = "gui/navReplays.blk"
  replays = null
  isReplayPressed = false
  curPage = 0
  replaysPerPage = 20

  statsColumnsOrderPvp  = [ "team", "name", "missionAliveTime", "score", "kills", "groundKills", "navalKills", "awardDamage", "aiKills",
                            "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "captureZone", "damageZone", "deaths" ]
  statsColumnsOrderRace = [ "team", "rowNo", "name", "raceFinishTime", "raceLap", "raceLastCheckpoint", "raceBestLapTime", "deaths" ]

  markup_mptable = {
    invert = false
    colorTeam = ""
    columns = {
      name = { width = "1@nameWidth +1@tablePad" }
    }
  }

  function initScreen()
  {
    ::set_presence_to_player("menu")
    scene.findObject("chapter_name").setValue(::loc("mainmenu/btnReplays"))
    scene.findObject("chapter_include_block").show(true)
    showSceneBtn("btn_open_folder", ::is_platform_windows)

    ::update_gamercards()
    loadReplays()

    local selItem = 0
    if (::current_replay != "")
    {
      foreach(index, replay in replays)
        if (replay.path == ::current_replay)
        {
          curPage = index / replaysPerPage
          selItem = index
          break
        }
      ::current_replay = ""
      ::current_replay_author = null
    }
    calculateReplaysPerPage()
    refreshList(selItem)
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    refreshList()
  }

  function loadReplays()
  {
    replays = ::get_replays_list()
    replays.sort(@(a,b) b.startTime <=> a.startTime || b.name <=> a.name)
  }

  function refreshList(selItem = 0)
  {
    local listObj = scene.findObject("items_list")
    if (!::checkObj(listObj))
      return

    if (selItem == 0)
    {
      local index = listObj.getValue()
      if (index >= 0 && index < listObj.childrenCount())
      {
        index--
        if (index < 0)
          index = 0
        selItem = index
      }
      selItem += curPage * replaysPerPage
    }

    local view = { items = [] }
    local lastIdx = ::min(replays.len(), ((curPage + 1) * replaysPerPage))
    for (local i = curPage * replaysPerPage; i < lastIdx; i++)
    {
      local iconName = "";
      local autosave = ::g_string.startsWith(replays[i].name, ::autosave_replay_prefix)
      local corrupted = replays[i]?.corrupted || replays[i]?.isVersionMismatch
      if (corrupted)
        iconName = "#ui/gameuiskin#icon_primary_fail.svg"
      else if (autosave)
        iconName = "#ui/gameuiskin#slot_modifications.svg"

      view.items.append({
        itemIcon = iconName
        id = "replay_" + i
        isSelected = i == selItem
      })
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    //* - text addition is ok
    //depends on ::get_new_replay_filename() format
    local defaultReplayNameMask =
      regexp2(@"2\d\d\d\.[0-3]\d\.[0-3]\d [0-2]\d\.[0-5]\d\.[0-5]\d*");
    for (local i = curPage * replaysPerPage; i < lastIdx; i++)
    {
      local obj = scene.findObject("txt_replay_" + i);
      local name = replays[i].name;
      local hasDateInName = ::g_string.startsWith(name, ::autosave_replay_prefix) || defaultReplayNameMask.match(name)
      local isCorrupted = ::getTblValue("corrupted", replays[i], false) || ::getTblValue("isVersionMismatch", replays[i], false)
      if (!hasDateInName && !isCorrupted)
      {
        local startTime = replays[i]?.startTime ?? -1
        if (startTime >= 0)
        {
          local date = time.buildDateTimeStr(startTime)
          name += ::colorize("fadedTextColor", ::loc("ui/parentheses/space", { text = date }))
        }
      }
      obj.setValue(name);
    }

    scene.findObject("optionlist-include").show(replays.len()>0)
    scene.findObject("info-text").setValue(replays.len()? "" : ::loc("mainmenu/noReplays"))
    if (replays.len() > 0)
    {
      doOpenInfo(selItem)
      doSelectList()
      showSceneBtn("btn_del_replay", true)
    }
    else
      foreach(btnName in ["btn_view_replay", "btn_upload_replay", "btn_rename_replay", "btn_del_replay"])
        showSceneBtn(btnName, false)

    ::generatePaginator(scene.findObject("paginator_place"),
                        this,
                        curPage,
                        ((replays.len() - 1) / replaysPerPage).tointeger())
  }

  function doOpenInfo(index)
  {
    local objDesc = scene.findObject("item_desc")
    //local objPic = objDesc.findObject("item_picture")
    //if (objPic != null)
    //{
    //  objPic["background-color"] = "#FFFFFFFF"
    //  objPic["background-image"] = pic
    //}

    if (index < 0 || index >= replays.len())
    {
      objDesc.findObject("item_desc_text").setValue("")
      return
    }

    local replayInfo = ::get_replay_info(replays[index].path)
    if (replayInfo == null)
    {
      objDesc.findObject("item_name").setValue(replays[index].name)
      objDesc.findObject("item_desc_text").setValue(::loc("msgbox/error_header"))
    }
    else
    {
      local corrupted = ::getTblValue("corrupted", replayInfo, false) // Any error reading headers (including version mismatch).
      local isVersionMismatch = ::getTblValue("isVersionMismatch", replayInfo, false) // Replay was recorded for in older game version.
      local isHeaderUnreadable = corrupted && !isVersionMismatch // Failed to read header (file not found or incomplete).

      local canWatch  = ::is_replay_turned_on() && (!corrupted || ::is_dev_version) && !::is_in_leaderboard_menu
      local canUpload = ::is_replay_turned_on() && !corrupted && ::is_in_leaderboard_menu && ::can_upload_replay()
      showSceneBtn("btn_view_replay", canWatch)
      showSceneBtn("btn_upload_replay", canUpload)
      showSceneBtn("btn_rename_replay", true)

      local headerText = ""
      local text = ""
      if (corrupted)
      {
        text = ::loc(isVersionMismatch ? "replays/versionMismatch" : "replays/corrupted")
        if (::is_dev_version && ("error" in replays[index]))
          text += ::colorize("warningTextColor", "\nDEBUG: " + replays[index].error) + "\n\n"

        if (!::is_dev_version || isHeaderUnreadable)
        {
          objDesc.findObject("item_name").setValue(replays[index].name)
          objDesc.findObject("item_desc_text").setValue(text)
          local tableObj = scene.findObject("session_results")
          if (::checkObj(tableObj))
            tableObj.show(false)
          return
        }
      }

      local startTime = replayInfo?.startTime ?? -1
      if (startTime >= 0)
        text += ::loc("options/mission_start_time") + ::loc("ui/colon") + time.buildDateTimeStr(startTime) + "\n"

      if (replayInfo.multiplayerGame)
        headerText += ::loc("mainmenu/btnMultiplayer")
      if (replayInfo.missionName.len() > 0)
      {
        if (replayInfo.multiplayerGame)
          headerText += ::loc("ui/colon");
        headerText += get_mission_name(replayInfo.missionName, replayInfo)
      }
      text += ::loc("options/time") + ::loc("ui/colon") + ::get_mission_time_text(replayInfo.environment) + "\n"
      text += ::loc("options/weather") + ::loc("ui/colon") + ::loc("options/weather" + replayInfo.weather) + "\n"
      text += ::loc("options/difficulty") + ::loc("ui/colon") + ::loc("difficulty" + replayInfo.difficulty) + "\n"

/*      local limits = ""
      if (replayInfo.isLimitedFuel && replayInfo.isLimitedAmmo)
        limits = ::loc("options/limitedFuelAndAmmo")
      else if (replayInfo.isLimitedFuel)
        limits = ::loc("options/limitedFuel")
      else if (replayInfo.isLimitedAmmo)
        limits = ::loc("options/limitedAmmo")
      else
        limits = ::loc("options/unlimited")

      text += ::loc("options/fuel_and_ammo") + ::loc("ui/colon") + limits + "\n" */
      local autosave = ::g_string.startsWith(replays[index].name, ::autosave_replay_prefix) //not replayInfo
      if (autosave)
        text += ::loc("msg/autosaveReplayDescription") + "\n"
      text += createSessionResultsTable(replayInfo)
      if ("sessionId" in replayInfo)
        text += ::loc("options/session") + ::loc("ui/colon") + replayInfo.sessionId + "\n"

      local fps = replays[index].text
      if (fps.len())
        text += fps + (::g_string.endsWith(fps, "\n") ? "" : "\n")

      objDesc.findObject("item_name").setValue(headerText)
      objDesc.findObject("item_desc_text").setValue(text)
    }
  }

  function createSessionResultsTable(replayInfo)
  {
    local addDescr = ""
    local tables = ""
    if (::has_feature("extendedReplayInfo") && "comments" in replayInfo)
    {
      local replayResultsTable = gatherReplayCommentData(replayInfo)
      addDescr = ::getTblValue("addDescr", replayResultsTable, "")

      foreach (name in replayResultsTable.tablesArray)
      {
        local rows = replayResultsTable.playersRows[name]
        tables += ::format("table{id:t='%s_table'; width:t='pw'; baseRow:t='yes' %s}",
          name, rows + ::getTblValue(name, replayResultsTable.addTableParams, ""))
      }
    }
    local tablesObj = scene.findObject("session_results")
    if (::checkObj(tablesObj))
    {
      tablesObj.show(tables!="")
      guiScene.replaceContentFromText(tablesObj.findObject("results_table_place"), tables, tables.len(), this)
    }

    return addDescr
  }

  function gatherReplayCommentData(replayInfo)
  {
    local data = {
      addDescr = ""
      playersRows = {}
      markups = {}
      headerArray = {}
      tablesArray = []
      rowHeader = {}
      addTableParams = {}
    }

    local replayComments = ::getTblValue("comments", replayInfo)
    if (!replayComments)
      return data

    local playersTables = {}
    local addTableParams = { teamA = { team = "blue" }, teamB = { team = "red" } }
    local replayParams = ["timePlayed", "author"]

    local gameType = replayInfo?.gameType ?? 0
    local gameMode = replayInfo?.gameMode ?? 0
    local isRace = !!(gameType & ::GT_RACE)
    local columnsOrder = isRace ? statsColumnsOrderRace : statsColumnsOrderPvp

    foreach(name in replayParams)
    {
      local value = ::getTblValue(name, replayComments)
      if (!value)
        continue

      if (name == "timePlayed")
        value = time.secondsToString(value)
      data.addDescr += (::loc("options/" + name) + ::loc("ui/colon") + value + "\n")
    }

    local mplayersList = replayMetadata.buildReplayMpTable(replays?[getCurrentReplayIndex()]?.path ?? "")
    if (mplayersList.len())
    {
      foreach (mplayer in mplayersList)
      {
        local teamName = ""
        if (mplayer.team == Team.A)
          teamName = "teamA"
        else if (mplayer.team == Team.B)
          teamName = "teamB"

        if (!(teamName in playersTables))
        {
          playersTables[teamName] <- []
          data.tablesArray.append(teamName)
          data.markups[teamName] <- clone markup_mptable
          data.markups[teamName].invert = false
          data.markups[teamName].colorTeam = teamName != ""? (teamName == "teamB"? "red" : "blue") : ""
        }

        if (mplayer.isLocal && teamName != "")
        {
          addTableParams[teamName].team = "blue"
          addTableParams[teamName == "teamA" ? "teamB" : "teamA"].team = "red"
        }

        playersTables[teamName].append(mplayer)
      }

      foreach(team, paramsTable in addTableParams)
      {
        local params = ""
        foreach(name, value in paramsTable)
          params += ::format("%s:t='%s'", name, value)
        data.addTableParams[team] <- params
      }
    }

    local missionName = ::getTblValue("missionName", replayInfo, "")
    local missionObjectivesMask = ::g_mission_type.getTypeByMissionName(missionName).getObjectives(
      { isWorldWar = ::getTblValue("isWorldWar", replayInfo, false) })

    local rowHeader = []
    local headerArray = []
    foreach(id in columnsOrder)
    {
      local paramType = ::g_mplayer_param_type.getTypeById(id)
      if (!paramType.isVisible(missionObjectivesMask, gameType, gameMode))
        continue

      local tooltip = paramType.getName()
      headerArray.append(id)
      rowHeader.append({
        tooltip       = tooltip
        fontIcon      = paramType.fontIcon
        fontIconType  = "fontIcon32"
        text          = paramType.fontIcon ? null : tooltip
        tdalign       = "center"
        active        = false
      })
    }

    if (data.tablesArray.len() == 2 && addTableParams[data.tablesArray[1]].team == "blue")
      data.tablesArray.reverse()

    foreach(idx, name in data.tablesArray)
    {
      data.rowHeader[name] <- rowHeader
      data.headerArray[name] <- headerArray

      local isMyTeam = idx == 0
      if (name == "teamA" || name == "teamB")
        data.rowHeader[name][0] = {
          image   = isMyTeam ? "#ui/gameuiskin#mp_logo_allies.svg" : "#ui/gameuiskin#mp_logo_axis.svg"
          tooltip = isMyTeam ? "#multiplayer/teamA" : "#multiplayer/teamB"
          tdalign = "center"
          active  = false
        }

      if (data.markups[name].invert)
        data.rowHeader[name].reverse()

      data.playersRows[name] <- ::buildTableRowNoPad("row_header", data.rowHeader[name], null, "class:t='smallIconsStyle'")
      data.playersRows[name] += ::build_mp_table(playersTables[name], data.markups[name], data.headerArray[name], playersTables[name].len())
    }

    return data
  }

  function getCurrentReplayIndex()
  {
    local list = scene.findObject("items_list")
    return list.getValue() + replaysPerPage * curPage
  }

  function onItemSelect(obj)
  {
    doOpenInfo(getCurrentReplayIndex())
  }

  function onStart()
  {
    onViewReplay()
  }

  doSelectList = @() ::move_mouse_on_child_by_value(scene.findObject("items_list"))

  function goBack()
  {
    if (isReplayPressed)
      return
    isReplayPressed = true
    ::HudBattleLog.reset()
    back_from_replays = null
    base.goBack()
  }

  function onViewReplay()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox())
      return

    ::set_presence_to_player("replay")
    guiScene.performDelayed(this, function()
    {
      if (isReplayPressed)
        return
      local index = getCurrentReplayIndex()
      if (index >= 0 && index < replays.len())
      {
        if (::getTblValue("corrupted", replays[index], false) && !::is_dev_version)
        {
          if (("isVersionMismatch" in replays[index]) && replays[index].isVersionMismatch)
          {
            msgBox("replay_corrupted", ::loc("replays/versionMismatch"),
            [["ok", function(){} ]], "ok")
          }
          else
          {
            msgBox("replay_corrupted", ::loc("replays/corrupted"),
            [["ok", function(){} ]], "ok")
          }
        }
        else
        {
          dagor.debug("gui_nav ::back_from_replays = ::gui_start_replays");
          ::back_from_replays = function() {
            ::SessionLobby.resetPlayersInfo()
            ::gui_start_menuReplays()
          }
          ::req_unlock_by_client("view_replay", false)
          ::current_replay = replays[index].path
          local replayInfo = ::get_replay_info(::current_replay)
          local comments = ::getTblValue("comments", replayInfo)
          ::current_replay_author = comments ? ::getTblValue("authorUserId", comments, null) : null
          ::on_view_replay(::current_replay)
          isReplayPressed = false
        }
      }
    })
  }

  function doDelReplay()
  {
    local index = getCurrentReplayIndex()
    if (index >= 0 && index < replays.len())
    {
      ::on_del_replay(replays[index].path)
      replays.remove(index)
      refreshList()
    }
  }

  function onRenameReplay()
  {
    local index = getCurrentReplayIndex()
    if (index >= 0 && index < replays.len())
    {
      local afterRenameFunc = function(newName)
      {
        loadReplays()
        refreshList()

        foreach(idx, replay in replays)
          if (replay.name == newName)
          {
            local list = scene.findObject("items_list")
            if (::checkObj(list))
              list.setValue(idx)
          }
      }

      ::gui_modal_rename_replay(replays[index].name, replays[index].path, this, afterRenameFunc);
    }
  }

  function onDelReplay()
  {
    msgBox("del_replay", ::loc("mainmenu/areYouSureDelReplay"),
    [
      ["yes", doDelReplay],
      ["no", doSelectList]
    ], "no")
  }

  function onOpenFolder()
  {
    ::on_open_replays_folder()
  }

  function onChapterSelect(obj) {}
  function onSelect(obj) {}
  function onListItemsFocusChange(obj) {}

  function calculateReplaysPerPage() {
    guiScene.applyPendingChanges(false)
    local replaysListObj = scene.findObject("items_list")
    replaysPerPage = ::g_dagui_utils.countSizeInItems(replaysListObj, 1, "1@baseTrHeight", 0, 0).itemsCountY
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class ::gui_handlers.RenameReplayHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    if (!scene)
      return goBack();

    baseName = baseName || ""
    baseName = ::g_string.startsWith(baseName, ::autosave_replay_prefix) ?
      baseName.slice(::autosave_replay_prefix.len()) : baseName
    scene.findObject("edit_box_window_header").setValue(::loc("mainmenu/replayName"));

    local editBoxObj = scene.findObject("edit_box_window_text")
    editBoxObj.show(true)
    editBoxObj.enable(true)
    editBoxObj.setValue(baseName)
    ::select_editbox(editBoxObj)
  }

  function checkName(newName)
  {
    if (!newName || newName == "")
      return false;
    foreach(c in "\\|/<>:?*\"")
      if (newName.indexof(c.tochar()) != null)
        return false
    if (::g_string.startsWith(newName, ::autosave_replay_prefix))
      return false;
    return true;
  }

  function onChangeValue(obj)
  {
    local newName = scene.findObject("edit_box_window_text").getValue()
    local btnOk = scene.findObject("btn_ok")
    if (::checkObj(btnOk))
      btnOk.inactiveColor = checkName(newName) ? "no" : "yes"
  }

  function onOk()
  {
    local newName = scene.findObject("edit_box_window_text").getValue();
    if (!checkName(newName))
    {
      msgBox("RenameReplayHandler_invalidName",::loc("msgbox/invalidReplayFileName"),
        [["ok", function() {} ]], "ok");
      return;
    }
    if (newName && newName != "")
    {
      if (afterRenameFunc && newName != baseName)
      {
        if (::rename_file(basePath, newName))
          afterRenameFunc.call(funcOwner, newName);
        else
          msgBox("RenameReplayHandler_error",::loc("msgbox/cantRenameReplayFile"),
            [["ok", function() {} ]], "ok");
      }

      if (afterFunc)
        afterFunc.call(funcOwner, newName);
    }
    guiScene.performDelayed(this, goBack);
  }

  scene = null

  baseName = null
  basePath = null
  funcOwner = null
  afterRenameFunc = null
  afterFunc = null

  wndType = handlerType.MODAL
  sceneBlkName = "gui/editBoxWindow.blk"
}
