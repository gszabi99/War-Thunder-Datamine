local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")

class ::gui_handlers.WwSquadList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/worldWar/wwBattleSquadList"

  country = null
  remainUnits = null
  squadListObj = null

  onWrapUpCb = null
  onWrapDownCb = null
  isFirstSquadInfoUpdate = true

  function getSceneTplView()
  {
    return { members = ::array(::g_squad_manager.MAX_SQUAD_SIZE, {}) }
  }

  function initScreen()
  {
    scene.setUserData(this)
    squadListObj = scene.findObject("squad_list")
    updateSquadInfoPanel()
  }

  function updateSquadInfoPanel()
  {
    local squadMembers = ::g_squad_manager.getMembers()
    local memberIdx = 0
    foreach (memberData in squadMembers)
    {
      if (!memberData.online)
        continue

      local memberObj = squadListObj.getChild(memberIdx)
      if (!::check_obj(memberObj))
        break

      updateSquadMember(memberData, memberObj)
      memberIdx++
    }

    for (local i = memberIdx; i < squadListObj.childrenCount(); i++)
    {
      local memberObj = squadListObj.getChild(i)
      if (::check_obj(memberObj))
        updateSquadMember(null, memberObj)
    }
  }

  function updateSquadMember(memberData, memberObj)
  {
    memberObj.show(!!memberData)
    if (!memberData)
      return

    memberObj.uid = memberData.uid
    memberObj.findObject("is_ready_icon").isReady =
      memberData.isReady ? "yes" : "no"
    local memberUnitsData = ::g_squad_utils.getMemberAvailableUnitsCheckingData(
      memberData, remainUnits, country)
    memberObj.findObject("has_vehicles_icon").isReady =
      memberUnitsData.joinStatus == memberStatus.READY ? "yes" : "no"
    memberObj.findObject("is_crews_ready_icon").isReady =
      memberData.isCrewsReady ? "yes" : "no"

    local alertText = ""
    local fullAlertText = ""
    if (!memberData.isWorldWarAvailable)
      alertText = ::loc("worldWar/noAccess")
    else if (!memberData.canPlayWorldWar)
    {
      alertText = ::loc("worldWar/noAccess")
      fullAlertText = ::g_world_war.getPlayWorldwarConditionText()
    }
    else if (!memberData.isReady)
      alertText = ::loc("multiplayer/state/player_is_not_ready")
    else if (memberUnitsData.joinStatus != memberStatus.READY)
      alertText = ::loc(::g_squad_utils.getMemberStatusLocId(memberUnitsData.joinStatus))
    else if (!memberData.isCrewsReady)
      alertText = ::loc("multiplayer/state/crews_not_ready")

    memberObj.findObject("cant_join_text").setValue(alertText)
    memberObj.findObject("member_name").setValue(memberData.name)

    local alertIconObj =  memberObj.findObject("alert_icon")
    if (!::check_obj(alertIconObj))
      return

    alertIconObj.show(!::u.isEmpty(fullAlertText))
    alertIconObj.tooltip = fullAlertText
  }

  function updateBattleData(battleCountry, battleRemainUnits)
  {
    country = battleCountry
    remainUnits = battleRemainUnits
    updateSquadInfoPanel()
  }

  function onEventSquadDataUpdated(params)
  {
    updateSquadInfoPanel()
  }

  onWrapUp   = @(obj) onWrapUpCb?(obj)
  onWrapDown = @(obj) onWrapDownCb?(obj)

  function onMemberRClick()
  {
    local curMemberIdx = squadListObj.getValue()
    if (curMemberIdx < 0 || curMemberIdx >= squadListObj.childrenCount())
      return

    local curMemberObj = squadListObj.getChild(curMemberIdx)
    if (!::check_obj(curMemberObj) || !curMemberObj?.uid)
      return

    local position = curMemberObj.getPosRC()
    position[1] += curMemberObj.getSize()[1]

    playerContextMenu.showMenu(null, this, {
      uid = curMemberObj.uid
      position = position
    })
  }

  function updateButtons(needShowList) {
    showSceneBtn("member_menu_open", needShowList)
    if (needShowList && squadListObj.childrenCount() > 0)
      squadListObj.select()
    else if (needShowList)
      restoreFocus()
  }
}
