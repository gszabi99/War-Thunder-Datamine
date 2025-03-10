from "%scripts/dagui_natives.nut" import ww_get_selected_armies_names
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { worldWarMapControls } = require("%scripts/worldWar/bhvWorldWarMap.nut")
let { wwUpdateHoverArmyName } = require("worldwar")
let { hoverArmyByName } = require("%scripts/worldWar/wwMapDataBridge.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")

gui_handlers.WwArmiesList <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/worldWarMapArmiesList.tpl"
  sceneBlkName = null
  contentBlockTplName = "%gui/worldWar/worldWarMapArmyItemEmpty.tpl"

  tabOrder = [
    ::g_ww_map_armies_status_tab_type.IDLE,
    ::g_ww_map_armies_status_tab_type.IN_MOVE,
    ::g_ww_map_armies_status_tab_type.ENTRENCHED,
    ::g_ww_map_armies_status_tab_type.IN_BATTLE
  ]

  lastTabSelected = null
  lastArmiesViewList = null
  selectedArmyName = null
  currentPage = 0
  curItemsPerPage = 0
  itemsPerPageWithPaginator = 0
  itemsPerPageWithoutPaginator = 0
  prevHoveredArmyName = null

  function initScreen() {
    this.itemsPerPageWithPaginator = this.getArmiesPerPage()
    this.itemsPerPageWithoutPaginator = this.getArmiesPerPage(true)

    let tabListObj = this.scene.findObject("armies_by_status_list")
    this.fillContent()
    if (checkObj(tabListObj))
      tabListObj.setValue(0)
  }

  function fillContent() {
    let contentObj = this.scene.findObject("armies_tab_content")
    if (!checkObj(contentObj))
      return

    let emptyViewData = ::g_ww_map_armies_status_tab_type.UNKNOWN.getEmptyContentViewData()
    for (local i = 0; i < this.itemsPerPageWithoutPaginator; i++)
      emptyViewData.army.append({})

    let markUpData = handyman.renderCached(this.contentBlockTplName, emptyViewData)
    this.guiScene.replaceContentFromText(contentObj, markUpData, markUpData.len(), this)
  }

  function getArmiesPerPage(withoutPaginator = false) {
    let contentObj = this.scene.findObject("armies_tab_content")
    if (!checkObj(contentObj))
      return 0

    let armiesContentSize = contentObj.getSize()
    let armyIconSize = this.guiScene.calcString("1@wwArmyIco", contentObj)
    local contentHeight = armiesContentSize[1]
    if (withoutPaginator) {
      let paginatorNestObj = this.scene.findObject("paginator_nest_obj")
      contentHeight += paginatorNestObj.getSize()[1]
    }
    return (armiesContentSize[0] / armyIconSize).tointeger()
                 * (contentHeight / armyIconSize).tointeger()
  }

  function getSceneTplContainerObj() {
    return this.scene
  }

  function getSceneTplView() {
    return { armiesByState = this.getArmiesStateTabs() }
  }

  function isValid() {
    return checkObj(this.scene) && checkObj(this.scene.findObject("armies_object"))
  }

  function getArmiesStateTabs() {
    return this.tabOrder.map(@(tab) tab.getTitleViewData())
  }

  function onArmiesByStatusTabChange(obj) {
    if (this.lastTabSelected != null)
      showObjById($"army_by_state_title_{this.lastTabSelected.status}", false, this.scene)

    this.lastTabSelected = ::g_ww_map_armies_status_tab_type.getTypeByStatus(obj.getValue())
    showObjById($"army_by_state_title_{this.lastTabSelected.status}", true, this.scene)

    this.currentPage = 0
    this.updateTabContent()
  }

  function fullViewUpdate() {
    this.updateTabs()
    this.updateTabContent()
  }

  function updateTabs() {
    foreach (tab in this.tabOrder) {
      let tabCountObj = this.scene.findObject($"army_by_state_title_count_{tab.status}")
      if (checkObj(tabCountObj))
        tabCountObj.setValue(tab.getArmiesCountText())
    }
  }

  function updateTabContent(updatedArmyNames = null) {
    this.updateCurItemsPerPage()
    this.updatePaginator()

    let contentObj = this.scene.findObject("armies_tab_content")
    if (!checkObj(contentObj))
      return

    let contentViewData = this.lastTabSelected.getContentViewData(this.curItemsPerPage, this.currentPage)
    if (!this.isHasChanges(contentViewData.army, updatedArmyNames))
      return

    for (local i = 0; i < contentViewData.army.len() || i < this.itemsPerPageWithoutPaginator; i++)
      this.updateScene(
        contentObj,
        i < contentViewData.army.len() ? contentViewData.army[i] : null,
        i
      )
  }

  function isHasChanges(newArmiesViewList, updatedArmyNames) {
    local result = false
    if (this.lastArmiesViewList == null || newArmiesViewList.len() != this.lastArmiesViewList.len())
      result = true
    else {
      for (local i = 0; i < newArmiesViewList.len(); i++)
        if (newArmiesViewList[i].name != this.lastArmiesViewList[i].name || newArmiesViewList[i].name in updatedArmyNames) {
          result = true
          break
        }
    }

    this.lastArmiesViewList = newArmiesViewList
    return result
  }

  function updateScene(contentObj, viewData, index) {
    let viewObj = contentObj.getChild(index)
    if (!checkObj(viewObj))
      return

    let isShow = viewData != null
    viewObj.show(isShow)
    viewObj.enable(isShow)
    if (!isShow)
      return

    viewObj["id"] = viewData.getId()
    viewObj["surrounded"] = viewData.getGroundSurroundingTime() ? "yes" : "no"
    viewObj["armyName"] = viewData.name
    viewObj["clanId"] = viewData.clanId()
    viewObj["selected"] = viewData.name == this.selectedArmyName ? "yes" : "no"

    let armyIconObj = viewObj.findObject("armyIcon")
    if (checkObj(armyIconObj)) {
      armyIconObj["team"] = viewData.getTeamColor()
      armyIconObj["isBelongsToMyClan"] = viewData.isBelongsToMyClan() ? "yes" : "no"
      armyIconObj.findObject("entrenchIcon").show(viewData.isEntrenched())

      let armyUnitTypeObj = armyIconObj.findObject("armyUnitType")
      if (checkObj(armyUnitTypeObj))
        armyUnitTypeObj["background-image"] = viewData.getUnitTypeIcon()
    }
  }

  function updateCurItemsPerPage() {
    let totalPages = this.lastTabSelected.getTotalPageCount(this.itemsPerPageWithoutPaginator)
    this.curItemsPerPage = totalPages > 1 ? this.itemsPerPageWithPaginator : this.itemsPerPageWithoutPaginator
  }

  function updatePaginator() {
    let pagesCount = this.lastTabSelected.getTotalPageCount(this.curItemsPerPage)
    let hasPaginator = pagesCount > 1
    let paginatorPlaceObj = showObjById("paginator_place", hasPaginator, this.scene)
    showObjById("paginator_nest_obj", hasPaginator, this.scene)
    if (hasPaginator)
      generatePaginator(paginatorPlaceObj, this, this.currentPage, pagesCount - 1, null, true, true)
  }

  function goToPage(obj) {
    this.currentPage = obj.to_page.tointeger()
    this.updateTabContent()
  }

  function onHoverArmyItem(obj) {
    wwUpdateHoverArmyName(obj.armyName)
    hoverArmyByName(obj.armyName)
    wwEvent("HoverArmyItem", { armyName = obj.armyName })
    this.prevHoveredArmyName = obj.armyName
  }

  function onHoverLostArmyItem(obj) {
    if (this.prevHoveredArmyName != obj.armyName)
      return
    wwUpdateHoverArmyName("")
    hoverArmyByName("")
    wwEvent("HoverLostArmyItem", { armyName = null })
  }

  function onClickArmy(obj) {
    if (this.selectedArmyName == obj.armyName)
      return

    this.setArmyViewSelection(obj.armyName, true)
    let wwArmy = g_world_war.getArmyByName(obj.armyName)
    if (!wwArmy)
      return

    wwEvent("ShowLogArmy", { wwArmy = wwArmy })

    let mapObj = this.guiScene["worldwar_map"]
    worldWarMapControls.selectArmy.call(worldWarMapControls, mapObj, obj.armyName)
    this.guiScene.playSound("ww_unit_select")
  }

  function setArmyViewSelection(armyName, isSelected) {
    if (armyName == this.selectedArmyName && isSelected)
      return

    let contentObj = this.scene.findObject("armies_tab_content")
    if (checkObj(contentObj))
      for (local i = 0; i < this.itemsPerPageWithoutPaginator; i++) {
        let viewObj = contentObj.getChild(i)
        if (!checkObj(viewObj))
          break

        if (viewObj.armyName == this.selectedArmyName)
          viewObj["selected"] = "no"
        else if (viewObj.armyName == armyName)
          viewObj["selected"] = isSelected ? "yes" : "no"
      }

    this.selectedArmyName = isSelected ? armyName : null
  }

  function onEventWWMapArmiesByStatusUpdated(params) {
    if (!this.isSceneActiveNoModals())
      return this.doWhenActiveOnce("fullViewUpdate")

    let armies = getTblValue("armies", params)
    if (u.isEmpty(armies))
      return

    this.updateTabs()

    let curTabArmies = armies.filter((@(lastTabSelected) @(army)  
      army.getActionStatus() == lastTabSelected.status)(this.lastTabSelected))

    if (curTabArmies.len() == 0)
      return

    this.updateTabContent(u.indexBy(curTabArmies, "name"))
  }

  function onEventWWMapArmySelected(_params) {
    let selectedArmyNames = ww_get_selected_armies_names()
    if (u.isEmpty(selectedArmyNames))
      return

    let armyName = selectedArmyNames[0]
    if (u.isEmpty(armyName))
      return

    this.setArmyViewSelection(armyName, true)
  }

  function onEventWWMapClearSelection(_params) {
    this.setArmyViewSelection(this.selectedArmyName, false)
  }
}
