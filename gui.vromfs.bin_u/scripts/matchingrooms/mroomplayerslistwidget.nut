from "%scripts/dagui_library.nut" import *
from "%scripts/teams.nut" import g_team
















let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { move_mouse_on_child } = require("%scripts/sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getMroomInfo } = require("%scripts/matchingRooms/mRoomInfoManager.nut")
let { getObjIdByPrefix } = require("%scripts/utils_sa.nut")
let { getRoomMembersInfoList } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { setMpTable, buildMpTable, updateTeamCssLabel } = require("%scripts/statistics/mpStatisticsUtil.nut")

let MRoomPlayersListWidget = class (BaseGuiHandlerWT) {
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
  focusedTeam = g_team.ANY
  isTablesInUpdate = false

  static TEAM_TBL_PREFIX = "players_table_"

  static function create(config) {
    if (!config?.teams || !checkObj(config?.scene)) {
      assert(false, "cant create playersListWidget - no teams or scene")
      return null
    }
    return handlersManager.loadHandler(get_gui_handler("MRoomPlayersListWidget"), config)
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
        content = buildMpTable([], markupData, this.columnsList)
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

  
  
  

  function getSelectedPlayer() {
    let objTbl = this.getFocusedTeamTableObj()
    return objTbl && this.playersInTeamTables?[this.focusedTeam]?[objTbl.getValue()]
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



  
  
  

  function getTeamTableId(team) {
    return this.TEAM_TBL_PREFIX + team.id
  }

  function updatePlayersTbl() {
    this.isTablesInUpdate = true
    let playersList = getRoomMembersInfoList(this.room)
    foreach (team in this.teams)
      this.updateTeamPlayersTbl(team, playersList)
    this.isTablesInUpdate = false
    this.onPlayerSelect()
  }

  function updateTeamPlayersTbl(team, playersList) {
    let objTbl = this.scene.findObject(this.getTeamTableId(team))
    if (!checkObj(objTbl))
      return

    let teamList = team == g_team.ANY ? playersList
      : playersList.filter(@(p) p.team.tointeger() == team.code)
    setMpTable(objTbl, teamList, {handler = this})
    updateTeamCssLabel(objTbl)

    this.playersInTeamTables[team] <- teamList

    
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
    this.focusedTeam = (g_team?[getObjIdByPrefix(obj, this.TEAM_TBL_PREFIX)] ?? this.focusedTeam)
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
    let fullRoom = getMroomInfo(this.room.roomId).getFullRoomData()
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
      move_mouse_on_child(this.scene.getChild(0), 0)
  }
}
register_gui_handler("MRoomPlayersListWidget", MRoomPlayersListWidget)

return { MRoomPlayersListWidget }
