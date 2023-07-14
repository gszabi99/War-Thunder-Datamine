//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { countSizeInItems } = require("%sqDagui/daguiUtil.nut")
let regexp2 = require("regexp2")
let time = require("%scripts/time.nut")
let replayMetadata = require("%scripts/replays/replayMetadata.nut")
let { is_replay_turned_on, is_replay_saved, get_replays_dir,
  get_new_replay_filename, on_save_replay, on_view_replay, get_replays_list,
  on_del_replay, on_open_replays_folder, get_replay_info } = require("replays")
let { is_benchmark_game_mode } = require("mission")
let { startsWith, endsWith } = require("%sqstd/string.nut")
let { reqUnlockByClient } = require("%scripts/unlocks/unlocksModule.nut")

const REPLAY_SESSION_ID_MIN_LENGHT = 16

let isCorruptedReplay = @(replay) (replay?.corrupted ?? false)
  || (replay?.isVersionMismatch ?? false)

local canPlayReplay = @(replay) replay != null && is_replay_turned_on()
  && (!isCorruptedReplay(replay) || ::is_dev_version)

::autosave_replay_max_count <- 100
::autosave_replay_prefix <- "#"

::current_replay <- ""
::current_replay_author <- null
::back_from_replays <- null

registerPersistentData("ReplayScreenGlobals", getroottable(), ["current_replay", "current_replay_author"])

::gui_start_replays <- function gui_start_replays() {
  ::gui_start_modal_wnd(::gui_handlers.ReplayScreen)
}

::gui_start_menuReplays <- function gui_start_menuReplays() {
  ::gui_start_mainmenu()
  ::gui_start_replays()
}

::gui_start_replay_battle <- function gui_start_replay_battle(sessionId, backFunc) {
  ::back_from_replays = function() {
    ::SessionLobby.resetPlayersInfo()
    backFunc()
  }
  reqUnlockByClient("view_replay")
  ::current_replay = ::get_replay_url_by_session_id(sessionId)
  ::current_replay_author = null
  on_view_replay(::current_replay)
}

::get_replay_url_by_session_id <- function get_replay_url_by_session_id(sessionId) {
  let sessionIdText = format("%0" + REPLAY_SESSION_ID_MIN_LENGHT + "s", sessionId.tostring())
  return loc("url/server_wt_game_replay", { sessionId = sessionIdText })
}

::gui_modal_rename_replay <- function gui_modal_rename_replay(base_name, base_path, func_owner, after_rename_func, after_func = null) {
  ::gui_start_modal_wnd(::gui_handlers.RenameReplayHandler, {
                                                              baseName = base_name
                                                              basePath = base_path
                                                              funcOwner = func_owner
                                                              afterRenameFunc = after_rename_func
                                                              afterFunc = after_func
                                                            })
}

::gui_modal_name_and_save_replay <- function gui_modal_name_and_save_replay(func_owner, after_func) {
  let baseName = get_new_replay_filename();
  let basePath = get_replays_dir() + "\\" + baseName;
  ::gui_modal_rename_replay(baseName, basePath, func_owner, null, after_func);
}

::autosave_replay <- function autosave_replay() {
  if (is_replay_saved())
    return;
  if (!::get_option_autosave_replays())
    return;
  if (is_benchmark_game_mode())
    return;

  let replays = get_replays_list();
  local autosaveCount = 0;
  for (local i = 0; i < replays.len(); i++) {
    if (replays[i].name.slice(0, 1) == ::autosave_replay_prefix)
      autosaveCount++;
  }
  let toDelete = autosaveCount - (::autosave_replay_max_count - 1);
  for (local d = 0; d < toDelete; d++) {
    local indexToDelete = -1;
    for (local i = 0; i < replays.len(); i++) {
      if (replays[i].name.slice(0, 1) != ::autosave_replay_prefix)
        continue;

      if (isCorruptedReplay(replays[i])) {
        indexToDelete = i;
        break;
      }
    }
    if (indexToDelete < 0) {
      //sort by time
      local oldestDate = -1
      for (local i = 0; i < replays.len(); i++) {
        if (replays[i].name.slice(0, 1) != ::autosave_replay_prefix)
          continue;

        let startTime = replays[i]?.startTime ?? -1
        if (oldestDate < 0 || startTime < oldestDate) {
          oldestDate = startTime
          indexToDelete = i;
        }
      }
    }

    if (indexToDelete >= 0) {
      on_del_replay(replays[indexToDelete].path);
      replays.remove(indexToDelete);
    }
  }

  local name = ::autosave_replay_prefix + get_new_replay_filename();
  on_save_replay(name); //ignore errors
}

::gui_handlers.ReplayScreen <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chapterModal.blk"
  sceneNavBlkName = "%gui/navReplays.blk"
  replays = null
  isReplayPressed = false
  curPage = 0
  replaysPerPage = 20

  listIdxPID = ::dagui_propid.add_name_id("listIdx")
  hoveredIdx = -1
  isMouseMode = true

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

  function initScreen() {
    ::set_presence_to_player("menu")
    this.scene.findObject("chapter_name").setValue(loc("mainmenu/btnReplays"))
    this.scene.findObject("chapter_include_block").show(true)
    this.showSceneBtn("btn_open_folder", is_platform_windows)

    ::update_gamercards()
    this.loadReplays()

    local selItem = 0
    if (::current_replay != "") {
      foreach (index, replay in this.replays)
        if (replay.path == ::current_replay) {
          this.curPage = index / this.replaysPerPage
          selItem = index
          break
        }
      ::current_replay = ""
      ::current_replay_author = null
    }
    this.calculateReplaysPerPage()
    this.updateMouseMode()
    this.refreshList(selItem)
  }

  function goToPage(obj) {
    this.curPage = obj.to_page.tointeger()
    this.refreshList(this.curPage * this.replaysPerPage)
  }

  function loadReplays() {
    this.replays = get_replays_list()
    this.replays.sort(@(a, b) b.startTime <=> a.startTime || b.name <=> a.name)
  }

  function refreshList(selItem) {
    let listObj = this.scene.findObject("items_list")
    if (!checkObj(listObj))
      return

    selItem = this.replays.len() == 0 ? -1 : clamp(selItem, 0, this.replays.len() - 1)
    this.curPage = max(0, selItem / this.replaysPerPage)

    let view = { items = [] }
    let firstIdx = this.curPage * this.replaysPerPage
    let lastIdx = min(this.replays.len(), ((this.curPage + 1) * this.replaysPerPage))
    for (local i = firstIdx; i < lastIdx; i++) {
      local iconName = "";
      let autosave = startsWith(this.replays[i].name, ::autosave_replay_prefix)
      if (isCorruptedReplay(this.replays[i]))
        iconName = "#ui/gameuiskin#icon_primary_fail.svg"
      else if (autosave)
        iconName = "#ui/gameuiskin#slot_modifications.svg"

      view.items.append({
        itemIcon = iconName
        id = "replay_" + i
        isSelected = i == selItem
        isNeedOnHover = ::show_console_buttons
      })
    }

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    for (local i = 0; i < listObj.childrenCount(); i++)
      listObj.getChild(i).setIntProp(this.listIdxPID, firstIdx + i)
    listObj.setValue(selItem % this.replaysPerPage)

    //* - text addition is ok
    //depends on get_new_replay_filename() format
    let defaultReplayNameMask =
      regexp2(@"2\d\d\d\.[0-3]\d\.[0-3]\d [0-2]\d\.[0-5]\d\.[0-5]\d*");
    for (local i = firstIdx; i < lastIdx; i++) {
      let obj = this.scene.findObject("txt_replay_" + i);
      local name = this.replays[i].name;
      let hasDateInName = startsWith(name, ::autosave_replay_prefix) || defaultReplayNameMask.match(name)
      if (!hasDateInName && !isCorruptedReplay(this.replays[i])) {
        let startTime = this.replays[i]?.startTime ?? -1
        if (startTime >= 0) {
          let date = time.buildDateTimeStr(startTime)
          name += colorize("fadedTextColor", loc("ui/parentheses/space", { text = date }))
        }
      }
      obj.setValue(name);
    }

    this.scene.findObject("optionlist-include").show(this.replays.len() > 0)
    this.scene.findObject("info-text").setValue(this.replays.len() ? "" : loc("mainmenu/noReplays"))

    ::generatePaginator(this.scene.findObject("paginator_place"),
                        this,
                        this.curPage,
                        ((this.replays.len() - 1) / this.replaysPerPage).tointeger())

    if (this.replays.len() > 0) {
      this.updateDescription()
      this.doSelectList()
    }
    this.updateButtons()
  }

  function updateButtons() {
    let curReplay = this.replays?[this.getCurrentReplayIndex()]

    let hoveredReplay = this.isMouseMode ? null : this.replays?[this.hoveredIdx]
    let isCurItemInFocus = curReplay != null && (this.isMouseMode || hoveredReplay == curReplay)

    ::showBtnTable(this.scene, {
        btn_view_replay   = isCurItemInFocus && canPlayReplay(curReplay)
        btn_rename_replay = isCurItemInFocus
        btn_del_replay    = isCurItemInFocus
    })
  }

  function updateDescription() {
    let index = this.getCurrentReplayIndex()
    let objDesc = this.scene.findObject("item_desc")
    //local objPic = objDesc.findObject("item_picture")
    //if (objPic != null)
    //{
    //  objPic["background-color"] = "#FFFFFFFF"
    //  objPic["background-image"] = pic
    //}

    if (index < 0 || index >= this.replays.len()) {
      objDesc.findObject("item_desc_text").setValue("")
      return
    }

    let replayInfo = get_replay_info(this.replays[index].path)
    if (replayInfo == null) {
      objDesc.findObject("item_name").setValue(this.replays[index].name)
      objDesc.findObject("item_desc_text").setValue(loc("msgbox/error_header"))
    }
    else {
      let corrupted = getTblValue("corrupted", replayInfo, false) // Any error reading headers (including version mismatch).
      let isVersionMismatch = getTblValue("isVersionMismatch", replayInfo, false) // Replay was recorded for in older game version.
      let isHeaderUnreadable = corrupted && !isVersionMismatch // Failed to read header (file not found or incomplete).

      local headerText = ""
      local text = ""
      if (corrupted) {
        text = loc(isVersionMismatch ? "replays/versionMismatch" : "replays/corrupted")
        if (::is_dev_version && ("error" in this.replays[index]))
          text += colorize("warningTextColor", "\nDEBUG: " + this.replays[index].error) + "\n\n"

        if (!::is_dev_version || isHeaderUnreadable) {
          objDesc.findObject("item_name").setValue(this.replays[index].name)
          objDesc.findObject("item_desc_text").setValue(text)
          let tableObj = this.scene.findObject("session_results")
          if (checkObj(tableObj))
            tableObj.show(false)
          return
        }
      }

      let startTime = replayInfo?.startTime ?? -1
      if (startTime >= 0)
        text += loc("options/mission_start_time") + loc("ui/colon") + time.buildDateTimeStr(startTime) + "\n"

      if (replayInfo.multiplayerGame)
        headerText += loc("mainmenu/btnMultiplayer")
      if (replayInfo.missionName.len() > 0) {
        if (replayInfo.multiplayerGame)
          headerText += loc("ui/colon");
        headerText += ::get_mission_name(replayInfo.missionName, replayInfo)
      }
      text += loc("options/time") + loc("ui/colon") + ::get_mission_time_text(replayInfo.environment) + "\n"
      text += loc("options/weather") + loc("ui/colon") + loc("options/weather" + replayInfo.weather) + "\n"
      text += loc("options/difficulty") + loc("ui/colon") + loc("difficulty" + replayInfo.difficulty) + "\n"

/*      local limits = ""
      if (replayInfo.isLimitedFuel && replayInfo.isLimitedAmmo)
        limits = loc("options/limitedFuelAndAmmo")
      else if (replayInfo.isLimitedFuel)
        limits = loc("options/limitedFuel")
      else if (replayInfo.isLimitedAmmo)
        limits = loc("options/limitedAmmo")
      else
        limits = loc("options/unlimited")

      text += loc("options/fuel_and_ammo") + loc("ui/colon") + limits + "\n" */
      let autosave = startsWith(this.replays[index].name, ::autosave_replay_prefix) //not replayInfo
      if (autosave)
        text += loc("msg/autosaveReplayDescription") + "\n"
      text += this.createSessionResultsTable(replayInfo)
      if ("sessionId" in replayInfo)
        text += loc("options/session") + loc("ui/colon") + replayInfo.sessionId + "\n"

      let fps = this.replays[index].text
      if (fps.len())
        text += fps + (endsWith(fps, "\n") ? "" : "\n")

      objDesc.findObject("item_name").setValue(headerText)
      objDesc.findObject("item_desc_text").setValue(text)
    }
  }

  function createSessionResultsTable(replayInfo) {
    local addDescr = ""
    local tables = ""
    if (hasFeature("extendedReplayInfo") && "comments" in replayInfo) {
      let replayResultsTable = this.gatherReplayCommentData(replayInfo)
      addDescr = getTblValue("addDescr", replayResultsTable, "")

      foreach (name in replayResultsTable.tablesArray) {
        let rows = replayResultsTable.playersRows[name]
        tables += format("table{id:t='%s_table'; width:t='pw'; baseRow:t='yes' %s}",
          name, rows + getTblValue(name, replayResultsTable.addTableParams, ""))
      }
    }
    let tablesObj = this.scene.findObject("session_results")
    if (checkObj(tablesObj)) {
      tablesObj.show(tables != "")
      this.guiScene.replaceContentFromText(tablesObj.findObject("results_table_place"), tables, tables.len(), this)
    }

    return addDescr
  }

  function gatherReplayCommentData(replayInfo) {
    let data = {
      addDescr = ""
      playersRows = {}
      markups = {}
      headerArray = {}
      tablesArray = []
      rowHeader = {}
      addTableParams = {}
    }

    let replayComments = getTblValue("comments", replayInfo)
    if (!replayComments)
      return data

    let playersTables = {}
    let addTableParams = { teamA = { team = "blue" }, teamB = { team = "red" } }
    let replayParams = ["timePlayed", "author"]

    let gameType = replayInfo?.gameType ?? 0
    let gameMode = replayInfo?.gameMode ?? 0
    let isRace = !!(gameType & GT_RACE)
    let columnsOrder = isRace ? this.statsColumnsOrderRace : this.statsColumnsOrderPvp

    foreach (name in replayParams) {
      local value = getTblValue(name, replayComments)
      if (!value)
        continue

      if (name == "timePlayed")
        value = time.secondsToString(value)
      data.addDescr += (loc("options/" + name) + loc("ui/colon") + value + "\n")
    }

    let mplayersList = replayMetadata.buildReplayMpTable(this.replays?[this.getCurrentReplayIndex()]?.path ?? "")
    if (mplayersList.len()) {
      foreach (mplayer in mplayersList) {
        local teamName = ""
        if (mplayer.team == Team.A)
          teamName = "teamA"
        else if (mplayer.team == Team.B)
          teamName = "teamB"

        if (!(teamName in playersTables)) {
          playersTables[teamName] <- []
          data.tablesArray.append(teamName)
          data.markups[teamName] <- clone this.markup_mptable
          data.markups[teamName].invert = false
          data.markups[teamName].colorTeam = teamName != "" ? (teamName == "teamB" ? "red" : "blue") : ""
        }

        if (mplayer.isLocal && teamName != "") {
          addTableParams[teamName].team = "blue"
          addTableParams[teamName == "teamA" ? "teamB" : "teamA"].team = "red"
        }

        playersTables[teamName].append(mplayer)
      }

      foreach (team, paramsTable in addTableParams) {
        local params = ""
        foreach (name, value in paramsTable)
          params += format("%s:t='%s'", name, value)
        data.addTableParams[team] <- params
      }
    }

    let missionName = getTblValue("missionName", replayInfo, "")
    let missionObjectivesMask = ::g_mission_type.getTypeByMissionName(missionName).getObjectives(
      { isWorldWar = getTblValue("isWorldWar", replayInfo, false) })

    let rowHeader = []
    let headerArray = []
    foreach (id in columnsOrder) {
      let paramType = ::g_mplayer_param_type.getTypeById(id)
      if (!paramType.isVisible(missionObjectivesMask, gameType, gameMode))
        continue

      let tooltip = paramType.getName()
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

    foreach (idx, name in data.tablesArray) {
      data.rowHeader[name] <- rowHeader
      data.headerArray[name] <- headerArray

      let isMyTeam = idx == 0
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

  function getCurrentReplayIndex() {
    let list = this.scene.findObject("items_list")
    return list.getValue() + this.replaysPerPage * this.curPage
  }

  function onItemSelect(_obj) {
    this.updateDescription()
    this.updateButtons()
  }

  function onItemDblClick(_obj) {
    if (::show_console_buttons)
      return

    this.onViewReplay()
  }

  function onItemHover(obj) {
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

  function updateMouseMode() {
    this.isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  }

  doSelectList = @() ::move_mouse_on_child_by_value(this.scene.findObject("items_list"))

  function goBack() {
    if (this.isReplayPressed)
      return
    this.isReplayPressed = true
    ::HudBattleLog.reset()
    ::back_from_replays = null
    base.goBack()
  }

  function onViewReplay() {
    let index = this.getCurrentReplayIndex()
    let curReplay = this.replays?[index]
    if (!canPlayReplay(curReplay))
      return

    if (!::g_squad_utils.canJoinFlightMsgBox())
      return

    ::set_presence_to_player("replay")
    this.guiScene.performDelayed(this, function() {
      if (this.isReplayPressed)
        return

      log("gui_nav ::back_from_replays = ::gui_start_replays");
      ::back_from_replays = function() {
        ::SessionLobby.resetPlayersInfo()
        ::gui_start_menuReplays()
      }
      reqUnlockByClient("view_replay")
      ::current_replay = this.replays[index].path
      let replayInfo = get_replay_info(::current_replay)
      let comments = getTblValue("comments", replayInfo)
      ::current_replay_author = comments ? getTblValue("authorUserId", comments, null) : null
      on_view_replay(::current_replay)
      this.isReplayPressed = false
    })
  }

  function doDelReplay() {
    let index = this.getCurrentReplayIndex()
    if (index >= 0 && index < this.replays.len()) {
      on_del_replay(this.replays[index].path)
      this.replays.remove(index)
      this.refreshList(min(index, this.replays.len() - 1))
    }
  }

  function onRenameReplay() {
    let index = this.getCurrentReplayIndex()
    if (index >= 0 && index < this.replays.len()) {
      let afterRenameFunc = function(_newName) {
        this.loadReplays()
        this.refreshList(index)
      }

      ::gui_modal_rename_replay(this.replays[index].name, this.replays[index].path, this, afterRenameFunc);
    }
  }

  function onDelReplay() {
    this.msgBox("del_replay", loc("mainmenu/areYouSureDelReplay"),
    [
      ["yes", this.doDelReplay],
      ["no", this.doSelectList]
    ], "no")
  }

  function onOpenFolder() {
    on_open_replays_folder()
  }

  function onChapterSelect(_obj) {}
  function onSelect(_obj) {}

  function calculateReplaysPerPage() {
    this.guiScene.applyPendingChanges(false)
    let replaysListObj = this.scene.findObject("items_list")
    this.replaysPerPage = countSizeInItems(replaysListObj, 1, "1@baseTrHeight", 0, 0).itemsCountY
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

::gui_handlers.RenameReplayHandler <- class extends ::gui_handlers.BaseGuiHandlerWT {
  function initScreen() {
    if (!this.scene)
      return this.goBack();

    this.baseName = this.baseName || ""
    this.baseName = startsWith(this.baseName, ::autosave_replay_prefix) ?
      this.baseName.slice(::autosave_replay_prefix.len()) : this.baseName
    this.scene.findObject("edit_box_window_header").setValue(loc("mainmenu/replayName"));

    let editBoxObj = this.scene.findObject("edit_box_window_text")
    editBoxObj.show(true)
    editBoxObj.enable(true)
    editBoxObj.setValue(this.baseName)
    ::select_editbox(editBoxObj)
  }

  function checkName(newName) {
    if (!newName || newName == "")
      return false;
    foreach (c in "\\|/<>:?*\"")
      if (newName.indexof(c.tochar()) != null)
        return false
    if (startsWith(newName, ::autosave_replay_prefix))
      return false;
    return true;
  }

  function onChangeValue(_obj) {
    let newName = this.scene.findObject("edit_box_window_text").getValue()
    let btnOk = this.scene.findObject("btn_ok")
    if (checkObj(btnOk))
      btnOk.inactiveColor = this.checkName(newName) ? "no" : "yes"
  }

  function onOk() {
    let newName = this.scene.findObject("edit_box_window_text").getValue();
    if (!this.checkName(newName)) {
      this.msgBox("RenameReplayHandler_invalidName", loc("msgbox/invalidReplayFileName"),
        [["ok", function() {} ]], "ok");
      return;
    }
    if (newName && newName != "") {
      if (this.afterRenameFunc && newName != this.baseName) {
        if (::rename_file(this.basePath, newName))
          this.afterRenameFunc.call(this.funcOwner, newName);
        else
          this.msgBox("RenameReplayHandler_error", loc("msgbox/cantRenameReplayFile"),
            [["ok", function() {} ]], "ok");
      }

      if (this.afterFunc)
        this.afterFunc.call(this.funcOwner, newName);
    }
    this.guiScene.performDelayed(this, this.goBack);
  }

  scene = null

  baseName = null
  basePath = null
  funcOwner = null
  afterRenameFunc = null
  afterFunc = null

  wndType = handlerType.MODAL
  sceneBlkName = "%gui/editBoxWindow.blk"
}
