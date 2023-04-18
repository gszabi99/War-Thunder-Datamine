//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")

::gui_handlers.WwOperationDescriptionCustomHandler <- class extends ::gui_handlers.WwMapDescription {
  sceneTplTeamStrenght = "%gui/worldWar/wwOperationDescriptionSideStrenght.tpl"
  sceneTplTeamArmyGroups = "%gui/worldWar/wwOperationDescriptionSideArmyGroups.tpl"

  slotbarActions = [ "sec_weapons", "weapons", "repair", "info" ]

  function setDescItem(newDescItem) {
    if (newDescItem && !(newDescItem instanceof ::WwOperation))
      return

    base.setDescItem(newDescItem)
  }

  function updateView() {
    let isShow = this.isVisible()
    this.updateVisibilities(isShow)
    if (!isShow)
      return

    this.updateDescription()

    if (::u.isEmpty(this.map))
      return

    this.fillOperationBackground()
    this.updateStatus()
    this.updateTeamsInfo()
    // to get corrct preview Map size updateMap() calls with delay
    // because Map size based on size of other objects
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.updateMap()
    })
  }

  function isVisible() {
    return this.descItem != null || this.map != null
  }

  function fillOperationBackground() {
    let operationBgObj = this.scene.findObject("operation_background")
    if (!checkObj(operationBgObj))
      return

    operationBgObj["background-image"] = this.map.getBackground()
  }

  function updateDescription() {
    let desctObj = this.scene.findObject("item_desc")
    if (checkObj(desctObj))
      desctObj.setValue(this.map.getDescription(false))
  }

  function updateMap() {
    if (!this.descItem && !this.map) {
      ::showBtn("world_war_map_block", false, this.scene)
      return
    }

    ::g_world_war_render.setPreviewCategories()

    let mapNestObj = this.scene.findObject("map_nest_obj")
    if (!checkObj(mapNestObj))
      return

    let descObj = this.scene.findObject("item_desc")
    let itemDescHeight = checkObj(descObj) ? descObj.getSize()[1] : 0
    let startDataObj = this.scene.findObject("operation_start_date")
    let operationDescText = this.scene.findObject("operation_short_info_text")
    let statusTextHeight = (checkObj(startDataObj) ? startDataObj.getSize()[1] : 0)
      + (checkObj(operationDescText) ? operationDescText.getSize()[1] : 0)

    let maxHeight = this.guiScene.calcString("ph-2@blockInterval", mapNestObj) - itemDescHeight - statusTextHeight
    local minSize = maxHeight
    let top = this.guiScene.calcString("2@blockInterval", mapNestObj) + itemDescHeight
    foreach (side in ::g_world_war.getCommonSidesOrder()) {
      let sideStrenghtObj = this.scene.findObject("strenght_" + ::ww_side_val_to_name(side))
      if (checkObj(sideStrenghtObj)) {
        let curWidth = ::g_dagui_utils.toPixels(
          this.guiScene,
          "pw-2*(" + sideStrenghtObj.getSize()[0] + "+1@blockInterval+2@framePadding)",
          mapNestObj
        )

        minSize = min(minSize, curWidth)
      }
    }

    mapNestObj.width = minSize
    mapNestObj.pos = "50%pw-50%w, 0.5*(" + maxHeight + "-" + minSize + ")+" + top

    if (this.descItem)
      ::g_world_war.updateOperationPreviewAndDo(this.descItem.id, Callback(function() {
          this.updateStatus()
          this.updateTeamsInfo()
        }, this), true)
    else
      ::ww_preview_operation_from_file(this.map.name)
  }

  function updateStatus() {
    if (!this.descItem)
      return

    let startDateObj = this.scene.findObject("operation_start_date")
    if (checkObj(startDateObj))
      startDateObj.setValue(
        loc("worldwar/operation/started", { date = this.descItem.getStartDateTxt() })
      )

    let activeBattlesCountObj = this.scene.findObject("operation_short_info_text")
    if (checkObj(activeBattlesCountObj)) {
      let battlesCount = ::g_world_war.getBattles(
        function(wwBattle) {
          return wwBattle.isActive()
        },
        true
      ).len()

      activeBattlesCountObj.setValue(
        battlesCount > 0
          ? loc("worldwar/operation/activeBattlesCount", { count = battlesCount })
          : loc("worldwar/operation/noActiveBattles")
      )
    }

    let isClanParticipateObj = this.scene.findObject("is_clan_participate_text")
    if (checkObj(isClanParticipateObj)) {
      local isMyClanParticipateText = ""
      if (this.descItem.isMyClanParticipate())
        foreach (idx, side in ::g_world_war.getCommonSidesOrder())
          if (this.descItem.isMyClanSide(side)) {
            isMyClanParticipateText = loc("worldwar/operation/isClanParticipate")
            isClanParticipateObj["text-align"] = (idx == 0 ? "left" : "right")
            break
          }

      isClanParticipateObj.setValue(isMyClanParticipateText)
    }
    ::g_world_war.updateConfigurableValues()
  }

  function updateTeamsInfo() {
    foreach (side in ::g_world_war.getCommonSidesOrder()) {
      let sideName = ::ww_side_val_to_name(side)
      let isInvert = side == SIDE_2

      let unitListObjPlace = this.scene.findObject("team_" + sideName + "_unit_info")
      let unitListBlk = ::handyman.renderCached(this.sceneTplTeamStrenght, this.getUnitsListViewBySide(side, isInvert))
      this.guiScene.replaceContentFromText(unitListObjPlace, unitListBlk, unitListBlk.len(), this)

      let armyGroupObjPlace = this.scene.findObject("team_" + sideName + "_army_group_info")
      let armyGroupViewData = this.getClanListViewDataBySide(side, isInvert, armyGroupObjPlace)
      let armyGroupsBlk = ::handyman.renderCached(this.sceneTplTeamArmyGroups, armyGroupViewData)
      this.guiScene.replaceContentFromText(armyGroupObjPlace, armyGroupsBlk, armyGroupsBlk.len(), this)

      let clanBlockTextObj = armyGroupObjPlace.findObject("clan_block_text")
      if (checkObj(clanBlockTextObj))
        clanBlockTextObj.setValue(this.descItem ?
          loc("worldwar/operation/participating_clans") :
          this.map.getClansConditionText(true))

      let countryesObjPlace = this.scene.findObject("team_" + sideName + "_countryes_info")
      let countryesMarkUpData = this.map.getCountriesViewBySide(side)
      this.guiScene.replaceContentFromText(countryesObjPlace, countryesMarkUpData, countryesMarkUpData.len(), this)
    }
  }

  function getUnitsListViewBySide(side, isInvert) {
    let unitsListView = this.map.getUnitsViewBySide(side)
    if (unitsListView.len() == 0)
      return {}

    return {
      sideName = ::ww_side_val_to_name(side)
      unitString = unitsListView
      invert = isInvert
    }
  }

  function getClanListViewDataBySide(side, isInvert, parentObj) {
    let viewData = {
        columns = []
        isInvert = isInvert
        isSingleColumn = false
      }

    if (!this.descItem)
      return viewData

    let armyGroups = ::g_world_war.getArmyGroupsBySide(side)
    let clansPerColumn = ::g_dagui_utils.countSizeInItems(parentObj, 1, "@leaderboardTrHeight",
      0, 0, 0, "2@wwWindowListBackgroundPadding").itemsCountY

    local armyGroupNames = null
    for (local i = 0; i < armyGroups.len(); i++) {
      if (i % clansPerColumn == 0) {
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

  function onUnitClick(unitObj) {
    unitContextMenuState({
      unitObj = unitObj
      actionsNames = this.getSlotbarActions()
      curEdiff = ::g_world_war.defaultDiffCode
      isSlotbarEnabled = false
    }.__update(this.getUnitParamsFromObj(unitObj)))
  }

  function onEventWWArmyManagersInfoUpdated(_p) {
    this.updateTeamsInfo()
  }
}
