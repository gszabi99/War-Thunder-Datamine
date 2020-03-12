class ::gui_handlers.WwArmiesList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/worldWar/worldWarMapArmiesList"
  sceneBlkName = null
  contentBlockTplName = "gui/worldWar/worldWarMapArmyItemEmpty"

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

  function initScreen()
  {
    itemsPerPageWithPaginator = getArmiesPerPage()
    itemsPerPageWithoutPaginator = getArmiesPerPage(true)

    local tabListObj = scene.findObject("armies_by_status_list")
    fillContent()
    if (::check_obj(tabListObj))
      tabListObj.setValue(0)
  }

  function fillContent()
  {
    local contentObj = scene.findObject("armies_tab_content")
    if (!::check_obj(contentObj))
      return

    local emptyViewData = ::g_ww_map_armies_status_tab_type.UNKNOWN.getEmptyContentViewData()
    for(local i = 0; i < itemsPerPageWithoutPaginator; i++)
      emptyViewData.army.append({})

    local markUpData = ::handyman.renderCached(contentBlockTplName, emptyViewData)
    guiScene.replaceContentFromText(contentObj, markUpData, markUpData.len(), this)
  }

  function getArmiesPerPage(withoutPaginator = false)
  {
    local contentObj = scene.findObject("armies_tab_content")
    if (!::check_obj(contentObj))
      return 0

    local armiesContentSize = contentObj.getSize()
    local armyIconSize = guiScene.calcString("1@wwArmyIco", contentObj)
    local contentHeight = armiesContentSize[1]
    if (withoutPaginator)
    {
      local paginatorNestObj = scene.findObject("paginator_nest_obj")
      contentHeight += paginatorNestObj.getSize()[1]
    }
    return (armiesContentSize[0] / armyIconSize).tointeger()
                 * (contentHeight / armyIconSize).tointeger()
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function getSceneTplView()
  {
    return { armiesByState = getArmiesStateTabs() }
  }

  function isValid()
  {
    return ::check_obj(scene) && ::check_obj(scene.findObject("armies_object"))
  }

  function getArmiesStateTabs()
  {
    return ::u.map(tabOrder, function(tab) { return tab.getTitleViewData() })
  }

  function onArmiesByStatusTabChange(obj)
  {
    if (lastTabSelected != null)
      showSceneBtn("army_by_state_title_" + lastTabSelected.status, false)

    lastTabSelected = ::g_ww_map_armies_status_tab_type.getTypeByStatus(obj.getValue())
    showSceneBtn("army_by_state_title_" + lastTabSelected.status, true)

    currentPage = 0
    updateTabContent()
  }

  function fullViewUpdate()
  {
    updateTabs()
    updateTabContent()
  }

  function updateTabs()
  {
    foreach(tab in tabOrder)
    {
      local tabCountObj = scene.findObject("army_by_state_title_count_" + tab.status)
      if (::check_obj(tabCountObj))
        tabCountObj.setValue(tab.getArmiesCountText())
    }
  }

  function updateTabContent(updatedArmyNames = null)
  {
    updateCurItemsPerPage()
    updatePaginator()

    local contentObj = scene.findObject("armies_tab_content")
    if (!::check_obj(contentObj))
      return

    local contentViewData = lastTabSelected.getContentViewData(curItemsPerPage, currentPage)
    if (!isHasChanges(contentViewData.army, updatedArmyNames))
      return

    for(local i = 0; i < contentViewData.army.len() || i < itemsPerPageWithoutPaginator; i++)
      updateScene(
        contentObj,
        i < contentViewData.army.len() ? contentViewData.army[i] : null,
        i
      )
  }

  function isHasChanges(newArmiesViewList, updatedArmyNames)
  {
    local result = false
    if (lastArmiesViewList == null || newArmiesViewList.len() != lastArmiesViewList.len())
      result = true
    else
    {
      for(local i = 0; i < newArmiesViewList.len(); i++)
        if (newArmiesViewList[i].name != lastArmiesViewList[i].name || newArmiesViewList[i].name in updatedArmyNames)
        {
          result = true
          break
        }
    }

    lastArmiesViewList = newArmiesViewList
    return result
  }

  function updateScene(contentObj, viewData, index)
  {
    local viewObj = contentObj.getChild(index)
    if (!::check_obj(viewObj))
      return

    local isShow = viewData != null
    viewObj.show(isShow)
    viewObj.enable(isShow)
    if (!isShow)
      return

    viewObj["id"] = viewData.getId()
    viewObj["surrounded"] = viewData.getGroundSurroundingTime() ? "yes" : "no"
    viewObj["armyName"] = viewData.name
    viewObj["clanId"] = viewData.clanId()
    viewObj["selected"] = viewData.name == selectedArmyName ? "yes" : "no"

    local armyIconObj = viewObj.findObject("armyIcon")
    if (::check_obj(armyIconObj))
    {
      armyIconObj["team"] = viewData.getTeamColor()
      armyIconObj["isBelongsToMyClan"] = viewData.isBelongsToMyClan() ? "yes" : "no"
      armyIconObj.findObject("entrenchIcon").show(viewData.isEntrenched())

      local armyUnitTypeObj = armyIconObj.findObject("armyUnitType")
      if (::check_obj(armyUnitTypeObj))
        armyUnitTypeObj.setValue(viewData.getUnitTypeCustomText())
    }
  }

  function updateCurItemsPerPage()
  {
    local totalPages = lastTabSelected.getTotalPageCount(itemsPerPageWithoutPaginator)
    curItemsPerPage = totalPages > 1 ? itemsPerPageWithPaginator : itemsPerPageWithoutPaginator
  }

  function updatePaginator()
  {
    local pagesCount = lastTabSelected.getTotalPageCount(curItemsPerPage)
    local hasPaginator = pagesCount > 1
    local paginatorPlaceObj = showSceneBtn("paginator_place", hasPaginator)
    showSceneBtn("paginator_nest_obj", hasPaginator)
    if (hasPaginator)
      ::generatePaginator(paginatorPlaceObj, this, currentPage, pagesCount - 1, null, true, true)
  }

  function goToPage(obj)
  {
    currentPage = obj.to_page.tointeger()
    updateTabContent()
  }

  function onHoverArmyItem(obj)
  {
    ::ww_update_hover_army_name(obj.armyName)
  }

  function onHoverLostArmyItem(obj)
  {
    ::ww_update_hover_army_name("")
  }

  function onClickArmy(obj)
  {
    if (selectedArmyName == obj.armyName)
      return

    setArmyViewSelection(obj.armyName, true)
    local wwArmy = ::g_world_war.getArmyByName(obj.armyName)
    if (!wwArmy)
      return

    ::ww_event("ShowLogArmy", { wwArmy = wwArmy })

    local mapObj = guiScene["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectArmy.call(::ww_gui_bhv.worldWarMapControls, mapObj, obj.armyName)
    ::play_gui_sound("ww_unit_select")
  }

  function setArmyViewSelection(armyName, isSelected)
  {
    if (armyName == selectedArmyName && isSelected)
      return

    local contentObj = scene.findObject("armies_tab_content")
    if (::check_obj(contentObj))
      for(local i = 0; i < itemsPerPageWithoutPaginator; i++)
      {
        local viewObj = contentObj.getChild(i)
        if (!::check_obj(viewObj))
          break

        if (viewObj.armyName == selectedArmyName)
          viewObj["selected"] = "no"
        else if (viewObj.armyName == armyName)
          viewObj["selected"] = isSelected ? "yes" : "no"
      }

    selectedArmyName = isSelected ? armyName : null
  }

  function onEventWWMapArmiesByStatusUpdated(params)
  {
    if (!isSceneActiveNoModals())
      return doWhenActiveOnce("fullViewUpdate")

    local armies = ::getTblValue("armies", params)
      if (::u.isEmpty(armies))
      return

    updateTabs()

    local curTabArmies = ::u.filter(
      armies,
      (@(lastTabSelected) function(army) {
        return army.getActionStatus() == lastTabSelected.status
      })(lastTabSelected)
    )

    if (curTabArmies.len() == 0)
      return

    updateTabContent(::u.indexBy(curTabArmies, "name"))
  }

  function onEventWWMapArmySelected(params)
  {
    local selectedArmyNames = ::ww_get_selected_armies_names()
    if (::u.isEmpty(selectedArmyNames))
      return

    local armyName = selectedArmyNames[0]
    if (::u.isEmpty(armyName))
      return

    setArmyViewSelection(armyName, true)
  }

  function onEventWWMapClearSelection(params)
  {
    setArmyViewSelection(selectedArmyName, false)
  }
}
