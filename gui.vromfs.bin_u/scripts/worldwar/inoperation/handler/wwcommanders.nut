let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

::gui_handlers.WwCommanders <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/worldWarCommandersInfo"
  sceneBlkName = null

  groupsHandlers = null

  static groupsInColumnMax = 5
  static groupsInRowMax = 3

  function getSceneTplView()
  {
    return getGroupsArray()
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function initScreen()
  {
    onSwitchCommandersSide(getObj("commanders_switch_box"))
    foreach(groupHandler in groupsHandlers)
      groupHandler.updateSelectedStatus()
  }

  function getGroupsArray()
  {
    let groupsView = []
    local useSwitchMode = false
    let view = { items = [] }
    let mapName = getOperationById(::ww_get_operation_id())?.getMapId() ?? ""
    groupsHandlers = []
    foreach(side in ::g_world_war.getSidesOrder())
    {
      let groups = ::g_world_war.getArmyGroupsBySide(side)
      if (groups.len() == 0)
        continue

      local myClanGroupView = null
      let sideGroupsView = []
      let armyCountry = []
      let myClanId = ::clan_get_my_clan_id()
      foreach (idx, group in groups)
      {
        let country = group.getArmyCountry()
        if (!::isInArray(country, armyCountry))
          armyCountry.append(country)

        let groupHandler = ::WwArmyGroupHandler(scene, group)
        groupsHandlers.append(groupHandler)

        let groupView = group.getView()
        if (group.getClanId() == myClanId)
          myClanGroupView = groupView
        else
          sideGroupsView.append(groupView)
      }

      if (myClanGroupView)
        sideGroupsView.insert(0, myClanGroupView)

      let selected = ::ww_get_player_side() == side
      useSwitchMode = useSwitchMode || sideGroupsView.len() > groupsInColumnMax

      let countryFlagsList = armyCountry.map(@(country) {
        image = getCustomViewCountryData(country, mapName).icon
      })

      local teamText = ::loc(getCustomViewCountryData(armyCountry[0], mapName).locId)
      if (armyCountry.len() > 1)
      {
        let postfix = ::ww_get_player_side() == side? "allies" : "enemies"
        teamText = ::loc("worldWar/side/" + postfix)
      }

      view.items.append({
        text = teamText
        image = countryFlagsList
        selected = selected
        params = "width:t='pw/2'"
      })

      groupsView.append({
        teamText = teamText
        armyCountryImg = countryFlagsList
        army = sideGroupsView
        customWidth = "pw/" + groupsInRowMax
      })
    }

    return {
      groups = groupsView
      hasTextAfterIcon = true
      isGroupItem = true
      addArmyClickCb = true
      checkMyArmy = true
      groupsNum = groupsView.len()
      useSwitchMode = useSwitchMode
      switchBoxItems = ::handyman.renderCached("%gui/commonParts/shopFilter", view)
    }
  }

  function onSwitchCommandersSide(obj)
  {
    if (!::check_obj(obj))
      return

    let placeObj = getObj("switch_mode_items_place")
    if (!::checkObj(placeObj))
      return

    let side = obj.getValue() + 1
    foreach (groupHandler in groupsHandlers)
    {
      let viewObj = placeObj.findObject(groupHandler.group.getView().getId())
      if (!::checkObj(viewObj))
        return

      viewObj.show(groupHandler.group.isMySide(side))
    }
  }

  function onHoverArmyItem(obj)
  {
    let clanId = obj.clanId
    let groups = ::g_world_war.getArmyGroups((@(clanId) function(group) { return group.clanId == clanId })(clanId))
    let groupArmyNames = []
    foreach (group in groups)
      groupArmyNames.extend(::ww_get_armies_names_of_armygroup({
        side         = ::ww_side_val_to_name(group.owner.side)
        country      = group.owner.country
        armyGroupIdx = group.owner.armyGroupIdx
      }))
    ::ww_update_popuped_armies_name(groupArmyNames)
  }

  function onClickArmy(obj)
  {
    ::showClanPage(obj.clanId, "", "")
  }

  function onHoverLostArmyItem(obj)
  {
    ::ww_update_popuped_armies_name([])
  }

  function onEventWWArmyManagersInfoUpdated(p)
  {
    let view = getSceneTplView()
    let data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
  }
}
