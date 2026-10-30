import "%scripts/user/playerContextMenu.nut" as playerContextMenu
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/daguiUtil.nut" import move_mouse_on_child_by_value
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/worldWar/worldWarGlobalStates.nut" import getPlayWorldwarConditionText
from "%scripts/squads/squadUtils.nut" import getMemberStatusLocId, getSquadMemberAvailableUnitsCheckingData
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import *

let WwSquadList = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/worldWar/wwBattleSquadList.tpl"

  country = null
  remainUnits = null
  squadListObj = null

  isFirstSquadInfoUpdate = true

  function getSceneTplView() {
    return { members = array(g_squad_manager.getSMMaxSquadSize(), {}) }
  }

  function initScreen() {
    this.scene.setUserData(this)
    this.squadListObj = this.scene.findObject("squad_list")
    this.updateSquadInfoPanel()
  }

  function updateSquadInfoPanel() {
    let squadMembers = g_squad_manager.getMembers()
    local memberIdx = 0
    foreach (memberData in squadMembers) {
      if (!memberData.online)
        continue

      let memberObj = this.squadListObj.getChild(memberIdx)
      if (!checkObj(memberObj))
        break

      this.updateSquadMember(memberData, memberObj)
      memberIdx++
    }

    for (local i = memberIdx; i < this.squadListObj.childrenCount(); i++) {
      let memberObj = this.squadListObj.getChild(i)
      if (checkObj(memberObj))
        this.updateSquadMember(null, memberObj)
    }
  }

  function updateSquadMember(memberData, memberObj) {
    memberObj.show(!!memberData)
    if (!memberData)
      return

    memberObj.uid = memberData.uid
    memberObj.findObject("is_ready_icon").isReady =
      memberData.isReady ? "yes" : "no"
    let memberUnitsData = getSquadMemberAvailableUnitsCheckingData(
      memberData, this.remainUnits, this.country)
    memberObj.findObject("has_vehicles_icon").isReady =
      memberUnitsData.joinStatus == memberStatus.READY ? "yes" : "no"
    memberObj.findObject("is_crews_ready_icon").isReady =
      memberData.isCrewsReady ? "yes" : "no"

    local alertText = ""
    local fullAlertText = ""
    if (!memberData.isWorldWarAvailable)
      alertText = loc("worldWar/noAccess")
    else if (!memberData.canPlayWorldWar) {
      alertText = loc("worldWar/noAccess")
      fullAlertText = getPlayWorldwarConditionText()
    }
    else if (!memberData.isReady)
      alertText = loc("multiplayer/state/player_is_not_ready")
    else if (memberUnitsData.joinStatus != memberStatus.READY)
      alertText = loc(getMemberStatusLocId(memberUnitsData.joinStatus))
    else if (!memberData.isCrewsReady)
      alertText = loc("multiplayer/state/crews_not_ready")

    memberObj.findObject("cant_join_text").setValue(alertText)
    memberObj.findObject("member_name").setValue(memberData.name)

    let alertIconObj =  memberObj.findObject("alert_icon")
    if (!checkObj(alertIconObj))
      return

    alertIconObj.show(!u.isEmpty(fullAlertText))
    alertIconObj.tooltip = fullAlertText
  }

  function updateBattleData(battleCountry, battleRemainUnits) {
    this.country = battleCountry
    this.remainUnits = battleRemainUnits
    this.updateSquadInfoPanel()
  }

  function onEventSquadDataUpdated(_params) {
    this.updateSquadInfoPanel()
  }

  function onMemberRClick() {
    let curMemberIdx = this.squadListObj.getValue()
    if (curMemberIdx < 0 || curMemberIdx >= this.squadListObj.childrenCount())
      return

    let curMemberObj = this.squadListObj.getChild(curMemberIdx)
    if (!checkObj(curMemberObj) || !curMemberObj?.uid)
      return

    let position = curMemberObj.getPosRC()
    position[1] += curMemberObj.getSize()[1]

    playerContextMenu.showMenu(null, this, {
      uid = curMemberObj.uid
      position = position
    })
  }

  function updateButtons(needShowList) {
    showObjById("member_menu_open", needShowList, this.scene)
    if (needShowList)
      move_mouse_on_child_by_value(this.squadListObj)
  }
}
register_gui_handler("WwSquadList", WwSquadList)

return freeze({ WwSquadList })
