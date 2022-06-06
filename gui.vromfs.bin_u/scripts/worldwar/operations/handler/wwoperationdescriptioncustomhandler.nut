let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")

::gui_handlers.WwOperationDescriptionCustomHandler <- class extends ::gui_handlers.WwMapDescription
{
  sceneTplTeamStrenght = "%gui/worldWar/wwOperationDescriptionSideStrenght"
  sceneTplTeamArmyGroups = "%gui/worldWar/wwOperationDescriptionSideArmyGroups"

  slotbarActions = [ "sec_weapons", "weapons", "repair", "info" ]

  function setDescItem(newDescItem)
  {
    if (newDescItem && !(newDescItem instanceof ::WwOperation))
      return

    base.setDescItem(newDescItem)
  }

  function updateView()
  {
    let isShow = isVisible()
    updateVisibilities(isShow)
    if (!isShow)
      return

    updateDescription()

    if (::u.isEmpty(map))
      return

    fillOperationBackground()
    updateStatus()
    updateTeamsInfo()
    // to get corrct preview Map size updateMap() calls with delay
    // because Map size based on size of other objects
    guiScene.performDelayed(this, function() {
      if (isValid())
        updateMap()
    })
  }

  function isVisible()
  {
    return descItem != null || map != null
  }

  function fillOperationBackground()
  {
    let operationBgObj = scene.findObject("operation_background")
    if (!::check_obj(operationBgObj))
      return

    operationBgObj["background-image"] = map.getBackground()
  }

  function updateDescription()
  {
    let desctObj = scene.findObject("item_desc")
    if (::check_obj(desctObj))
      desctObj.setValue(map.getDescription(false))
  }

  function updateMap()
  {
    if (!descItem && !map)
    {
      ::showBtn("world_war_map_block", false, scene)
      return
    }

    ::g_world_war_render.setPreviewCategories()

    let mapNestObj = scene.findObject("map_nest_obj")
    if (!::checkObj(mapNestObj))
      return

    let descObj = scene.findObject("item_desc")
    let itemDescHeight = ::checkObj(descObj) ? descObj.getSize()[1] : 0
    let startDataObj = scene.findObject("operation_start_date")
    let operationDescText = scene.findObject("operation_short_info_text")
    let statusTextHeight = (::checkObj(startDataObj) ? startDataObj.getSize()[1] : 0)
      + (::checkObj(operationDescText) ? operationDescText.getSize()[1] : 0)

    let maxHeight = guiScene.calcString("ph-2@blockInterval", mapNestObj) - itemDescHeight - statusTextHeight
    local minSize = maxHeight
    let top = guiScene.calcString("2@blockInterval", mapNestObj) + itemDescHeight
    foreach(side in ::g_world_war.getCommonSidesOrder())
    {
      let sideStrenghtObj = scene.findObject("strenght_" + ::ww_side_val_to_name(side))
      if (::checkObj(sideStrenghtObj))
      {
        let curWidth = ::g_dagui_utils.toPixels(
          guiScene,
          "pw-2*(" + sideStrenghtObj.getSize()[0] + "+1@blockInterval+2@framePadding)",
          mapNestObj
        )

        minSize = min(minSize, curWidth)
      }
    }

    mapNestObj.width = minSize
    mapNestObj.pos = "50%pw-50%w, 0.5*(" + maxHeight + "-" + minSize + ")+" + top

    if (descItem)
      ::g_world_war.updateOperationPreviewAndDo(descItem.id, ::Callback(function() {
          updateStatus()
          updateTeamsInfo()
        }, this), true)
    else
      ::ww_preview_operation_from_file(map.name)
  }

  function updateStatus()
  {
    if (!descItem)
      return

    let startDateObj = scene.findObject("operation_start_date")
    if (::checkObj(startDateObj))
      startDateObj.setValue(
        ::loc("worldwar/operation/started", { date = descItem.getStartDateTxt() })
      )

    let activeBattlesCountObj = scene.findObject("operation_short_info_text")
    if (::checkObj(activeBattlesCountObj))
    {
      let battlesCount = ::g_world_war.getBattles(
        function(wwBattle) {
          return wwBattle.isActive()
        },
        true
      ).len()

      activeBattlesCountObj.setValue(
        battlesCount > 0
          ? ::loc("worldwar/operation/activeBattlesCount", { count = battlesCount } )
          : ::loc("worldwar/operation/noActiveBattles")
      )
    }

    let isClanParticipateObj = scene.findObject("is_clan_participate_text")
    if (::checkObj(isClanParticipateObj))
    {
      local isMyClanParticipateText = ""
      if (descItem.isMyClanParticipate())
        foreach(idx, side in ::g_world_war.getCommonSidesOrder())
          if (descItem.isMyClanSide(side))
          {
            isMyClanParticipateText = ::loc("worldwar/operation/isClanParticipate")
            isClanParticipateObj["text-align"] = (idx == 0 ? "left" : "right")
            break
          }

      isClanParticipateObj.setValue(isMyClanParticipateText)
    }
    ::g_world_war.updateConfigurableValues()
  }

  function updateTeamsInfo()
  {
    foreach(side in ::g_world_war.getCommonSidesOrder())
    {
      let sideName = ::ww_side_val_to_name(side)
      let isInvert = side == ::SIDE_2

      let unitListObjPlace = scene.findObject("team_" + sideName + "_unit_info")
      let unitListBlk = ::handyman.renderCached(sceneTplTeamStrenght, getUnitsListViewBySide(side, isInvert))
      guiScene.replaceContentFromText(unitListObjPlace, unitListBlk, unitListBlk.len(), this)

      let armyGroupObjPlace = scene.findObject("team_" + sideName + "_army_group_info")
      let armyGroupViewData = getClanListViewDataBySide(side, isInvert, armyGroupObjPlace)
      let armyGroupsBlk = ::handyman.renderCached(sceneTplTeamArmyGroups, armyGroupViewData)
      guiScene.replaceContentFromText(armyGroupObjPlace, armyGroupsBlk, armyGroupsBlk.len(), this)

      let clanBlockTextObj = armyGroupObjPlace.findObject("clan_block_text")
      if (::check_obj(clanBlockTextObj))
        clanBlockTextObj.setValue(descItem ?
          ::loc("worldwar/operation/participating_clans") :
          map.getClansConditionText(true))

      let countryesObjPlace = scene.findObject("team_" + sideName + "_countryes_info")
      let countryesMarkUpData = map.getCountriesViewBySide(side)
      guiScene.replaceContentFromText(countryesObjPlace, countryesMarkUpData, countryesMarkUpData.len(), this)
    }
  }

  function getUnitsListViewBySide(side, isInvert)
  {
    let unitsListView = map.getUnitsViewBySide(side)
    if (unitsListView.len() == 0)
      return {}

    return {
      sideName = ::ww_side_val_to_name(side)
      unitString = unitsListView
      invert = isInvert
    }
  }

  function getClanListViewDataBySide(side, isInvert, parentObj)
  {
    let viewData = {
        columns = []
        isInvert = isInvert
        isSingleColumn = false
      }

    if (!descItem)
      return viewData

    let armyGroups = ::g_world_war.getArmyGroupsBySide(side)
    let clansPerColumn = ::g_dagui_utils.countSizeInItems(parentObj, 1, "@leaderboardTrHeight",
      0, 0, 0, "2@wwWindowListBackgroundPadding").itemsCountY

    local armyGroupNames = null
    for(local i = 0; i < armyGroups.len(); i++)
    {
      if (i % clansPerColumn == 0)
      {
        armyGroupNames = []
        let groupView = armyGroups[i].getView()
        if (groupView == null)
          continue

        viewData.columns.append({
          armyGroupNames = armyGroupNames
          managers = groupView
        })
      }

      if ("name" in armyGroups[i])
        armyGroupNames.append({ name = armyGroups[i].name })
    }
    if (isInvert)
      viewData.columns.reverse()

    viewData.isSingleColumn = viewData.columns.len() == 1

    return viewData
  }

  function onUnitClick(unitObj)
  {
    unitContextMenuState({
      unitObj = unitObj
      actionsNames = getSlotbarActions()
      curEdiff = ::g_world_war.defaultDiffCode
      isSlotbarEnabled = false
    }.__update(getUnitParamsFromObj(unitObj)))
  }

  function onEventWWArmyManagersInfoUpdated(p)
  {
    updateTeamsInfo()
  }
}
