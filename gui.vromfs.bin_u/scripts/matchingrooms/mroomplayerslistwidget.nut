//checked for plus_string
from "%scripts/dagui_library.nut" import *

/*
 API:
 static create(config)
   config:
     scene (required) - object where need to create players lists
     teams (required) - list of teams (g_team) to show in separate columns
     room - room to gather members data (null == current SessionLobby room)
     columnsList - list of table columns to show

     onPlayerSelectCb(player) - callback on player select
     onPlayerDblClickCb(player) - callback on player double click
     onPlayerRClickCb(player) = callback on player RClick
*/


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.MRoomPlayersListWidget <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/mpLobby/playersList.tpl"

  teams = null
  room = null
  columnsList = ["team", "country", "name", "status"]

  onPlayerSelectCb = null
  onPlayerDblClickCb = null
  onPlayerRClickCb = null
  onTablesHoverChange = null

  playersInTeamTables = null
  focusedTeam = ::g_team.ANY
  isTablesInUpdate = false

  static TEAM_TBL_PREFIX = "players_table_"

  static function create(config) {
    if (!getTblValue("teams", config) || !checkObj(getTblValue("scene", config))) {
      assert(false, "cant create playersListWidget - no teams or scene")
      return null
    }
    return handlersManager.loadHandler(gui_handlers.MRoomPlayersListWidget, config)
  }

  function getSceneTplView() {
    let view = {
      teamsAmount = this.teams.len()
      teams = []
    }

    let markupData = {
      tr_size = "pw, @baseTrHeight"
      trOnHover = "onPlayerHover"
      columns = {
        name = { width = "fw" }
      }
    }
    foreach (idx, team in this.teams) {
      markupData.invert <- idx == 0  && this.teams.len() == 2
      view.teams.append(
      {
        isFirst = idx == 0
        tableId = this.getTeamTableId(team)
        content = ::build_mp_table([], markupData, this.columnsList)
      })
    }
    return view
  }

  function initScreen() {
    this.setFullRoomInfo()
    this.playersInTeamTables = {}
    this.focusedTeam = this.teams[0]
    this.updatePlayersTbl()
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getSelectedPlayer() {
    let objTbl = this.getFocusedTeamTableObj()
    return objTbl && getTblValue(objTbl.getValue(), getTblValue(this.focusedTeam, this.playersInTeamTables))
  }

  function getSelectedRowPos() {
    let objTbl = this.getFocusedTeamTableObj()
    if (!objTbl)
      return null
    let rowNum = objTbl.getValue()
    if (rowNum < 0 || rowNum >= objTbl.childrenCount())
      return null
    let rowObj = objTbl.getChild(rowNum)
    let topLeftCorner = rowObj.getPosRC()
    return [topLeftCorner[0], topLeftCorner[1] + rowObj.getSize()[1]]
  }



  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getTeamTableId(team) {
    return this.TEAM_TBL_PREFIX + team.id
  }

  function updatePlayersTbl() {
    this.isTablesInUpdate = true
    let playersList = ::SessionLobby.getMembersInfoList(this.room)
    foreach (team in this.teams)
      this.updateTeamPlayersTbl(team, playersList)
    this.isTablesInUpdate = false
    this.onPlayerSelect()
  }

  function updateTeamPlayersTbl(team, playersList) {
    let objTbl = this.scene.findObject(this.getTeamTableId(team))
    if (!checkObj(objTbl))
      return

    let teamList = team == ::g_team.ANY ? playersList
      : playersList.filter(@(p) p.team.tointeger() == team.code)
    ::set_mp_table(objTbl, teamList, {handler = this})
    ::update_team_css_label(objTbl)

    this.playersInTeamTables[team] <- teamList

    //update cur value
    if (teamList.len() > 0) {
      let curValue = objTbl.getValue() ?? -1
      let validValue = clamp(curValue, 0, teamList.len() - 1)
      if (curValue != validValue)
        objTbl.setValue(validValue)
    }
  }

  function getFocusedTeamTableObj() {
    return this.getObj(this.getTeamTableId(this.focusedTeam))
  }

  function updateFocusedTeamByObj(obj) {
    this.focusedTeam = getTblValue(::getObjIdByPrefix(obj, this.TEAM_TBL_PREFIX), ::g_team, this.focusedTeam)
  }

  function onTableClick(obj) {
    this.updateFocusedTeamByObj(obj)
    this.onPlayerSelect()
  }

  function onTableSelect(obj) {
    if (this.isTablesInUpdate)
      return
    this.updateFocusedTeamByObj(obj)
    this.onPlayerSelect()
  }

  function onPlayerSelect() {
    if (this.onPlayerSelectCb)
      this.onPlayerSelectCb(this.getSelectedPlayer())
  }

  function onTableDblClick()    { if (this.onPlayerDblClickCb) this.onPlayerDblClickCb(this.getSelectedPlayer()) }
  function onTableRClick()      { if (this.onPlayerRClickCb)   this.onPlayerRClickCb(this.getSelectedPlayer()) }
  function onTableHover(obj)    { if (this.onTablesHoverChange) this.onTablesHoverChange(obj.id, obj.isHovered()) }

  function onPlayerHover(obj) {
    if (!checkObj(obj) || !obj.isHovered())
      return
    let value = to_integer_safe(obj?.rowIdx, -1, false)
    let listObj = obj.getParent()
    if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
      listObj.setValue(value)
  }

  function onEventLobbyMembersChanged(_p) {
    this.updatePlayersTbl()
  }

  function onEventLobbyMemberInfoChanged(_p) {
    this.updatePlayersTbl()
  }

  function onEventLobbySettingsChange(_p) {
    this.updatePlayersTbl()
  }

  function setFullRoomInfo() {
    if (!this.room)
      return
    let fullRoom = ::g_mroom_info.get(this.room.roomId).getFullRoomData()
    if (fullRoom)
      this.room = fullRoom
  }

  function onEventMRoomInfoUpdated(p) {
    if (this.room && p.roomId == this.room.roomId) {
      this.setFullRoomInfo()
      this.updatePlayersTbl()
    }
  }

  function moveMouse() {
    if (this.scene.childrenCount() > 0)
      ::move_mouse_on_child(this.scene.getChild(0), 0)
  }
}