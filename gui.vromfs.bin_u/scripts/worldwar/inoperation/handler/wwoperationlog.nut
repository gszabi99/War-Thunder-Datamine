let { WW_LOG_BATTLE_TOOLTIP } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")

const WW_MAX_TOP_LOGS_NUMBER_TO_REMOVE = 5

::gui_handlers.WwOperationLog <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = null
  sceneBlkName = "%gui/worldWar/worldWarOperationLogInfo"
  logRowTplName = "%gui/worldWar/wwOperationLogRow"

  prevLogDate = ""
  viewLogAmount = 0
  isLogPageScrolledDown = false

  logFrameObj = null
  logContainerObj = null
  emptyLogChild = null

  selectedArmyName = ""
  hoveredArmyName = ""

  function getSceneTplView()
  {
    return {}
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function isValid()
  {
    return ::check_obj(scene) && ::check_obj(logFrameObj)
  }

  function initScreen()
  {
    logFrameObj = scene.findObject("ww_operation_log_frame")
    logContainerObj = scene.findObject("ww_operation_log")

    prevLogDate = ""
    ::g_ww_logs.applyLogsFilter()
    buildEmptyLogsBlock()
    fillLogBlock()
    ::g_ww_logs.saveLastReadLogMark()
  }

  function buildEmptyLogsBlock()
  {
    let emptyBattleArmies = ::array(WW_LOG_BATTLE.MAX_ARMIES_PER_SIDE, {})
    let emptyDamagedArmies = []
    for (local i = 0; i < WW_LOG_BATTLE.MAX_DAMAGED_ARMIES; i++)
      emptyDamagedArmies.append({idx = i})

    let emptyLog = {battleArmy = emptyBattleArmies, damagedArmy = emptyDamagedArmies}
    let logsList = ::array(WW_LOG_MAX_DISPLAY_AMOUNT, emptyLog)
    let logData = ::handyman.renderCached(logRowTplName, {operationLogRow = logsList})
    guiScene.replaceContentFromText(logContainerObj, logData, logData.len(), this)
    emptyLogChild = ::handyman.renderCached(logRowTplName, {operationLogRow = [emptyLog]})
  }

  function onEventWWNewLogsAdded(params = {})
  {
    let isLogMarkUsed = ::getTblValue("isLogMarkUsed", params, false)
    if (!isLogMarkUsed && !isLogPageScrolledDown)
    {
      configShowNextLogsBlock({isForcedShow = true})
      return
    }

    if (isLogMarkUsed)
      ::g_ww_logs.viewIndex = 0
    else if (isLogPageScrolledDown)
      ::g_ww_logs.viewIndex = ::max(::g_ww_logs.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT, 0)

    fillLogBlock(false, null, !isLogMarkUsed && isLogPageScrolledDown)
  }

  function onEventWWNoLogsAdded(params = {})
  {
    configManageBlocks()
  }

  function fillLogBlock(scrollDefined = false, scrollId = null, isNewOperationEventLog = false)
  {
    if (!::check_obj(logContainerObj))
      return

    let emptyTextObj = scene.findObject("ww_operation_empty_log")
    if (::check_obj(emptyTextObj))
      emptyTextObj.show(!::g_ww_logs.filtered.len())

    if (isNewOperationEventLog && ::g_ww_logs.viewIndex in ::g_ww_logs.filtered)
    {
      let firstLog = ::g_ww_logs.loaded[::g_ww_logs.filtered[::g_ww_logs.viewIndex]]
      let logAmountToDestroy = getOutsideBlockLogAmount(firstLog.id)
      removeOutsideBlockLogs(logAmountToDestroy)
      addMissingLogs(logAmountToDestroy)
    }

    let scrollTargetId = scrollDefined ? scrollId : getScrollTargetId()
    markPreviousLogsAsReaded()
    guiScene.setUpdatesEnabled(false, false)
    viewLogAmount = 0
    for(local i = 0; i < logContainerObj.childrenCount(); i++)
    {
      let logObj = logContainerObj.getChild(i)
      let logIdx = i + ::g_ww_logs.viewIndex
      if (!(logIdx in ::g_ww_logs.filtered))
      {
        logObj.show(false)
        continue
      }

      let num = ::g_ww_logs.filtered[logIdx]
      let log = ::g_ww_logs.loaded[num]
      log.isReaded = true

      let logView = ::g_ww_logs.logsViews[log.id]
      logView.setPrevLogDateValue(prevLogDate)
      logView.setIsFirstRowValue(logIdx == ::g_ww_logs.viewIndex)
      fillLogObject(logObj, logView)
      prevLogDate = logView.getDate()

      viewLogAmount++
    }

    logContainerObj.getChild(0).scrollToView()
    guiScene.setUpdatesEnabled(true, true)
    configManageBlocks()
    configScrollPosition(scrollTargetId, isNewOperationEventLog)

    if (!selectedArmyName.len())
    {
      let selectedArmies = ::ww_get_selected_armies_names()
      if (selectedArmies.len())
        selectedArmyName = selectedArmies[0]
    }
    setArmyObjsSelected(findArmyObjsInLog(selectedArmyName), true)

    ::ww_event("NewLogsDisplayed", { amount = ::g_ww_logs.getUnreadedNumber() })
  }

  function setObjParamsById(objNest, id, paramsToSet)
  {
    let obj = objNest.findObject(id)
    if (!::check_obj(obj))
      return

    foreach (name, value in paramsToSet)
      if (name == "text")
        obj.setValue(value)
      else
        obj[name] = value
  }

  function fillLogObject(obj, logView)
  {
    obj.show(true)
    let logId = logView.getId()
    if (obj?.id == logId)
      return

    obj.id = logId
    obj.findObject("date").show(!logView.isFirst() && logView.showDate())

    foreach (blockId, blockData in logView.getBasicInfoTable())
      setObjParamsById(obj, blockId, blockData)

    let bodyObj = obj.findObject("log_body")
    if (!::check_obj(bodyObj))
      return

    let armyData = logView.getArmyData()
    setObjParamsById(bodyObj, "log_text", logView.getTextInfoTable())
    fillLogArmyContainer(armyData ? armyData.army[0] : null, "army", bodyObj)
    fillLogBattleObject(bodyObj, logView.getBattleData())
    fillLogDamagedArmiesObject(bodyObj, logView.getDmgArmiesData())
  }

  function fillLogDamagedArmiesObject(bodyObj, dmgArmiesData)
  {
    for(local i = 0; i < WW_LOG_BATTLE.MAX_DAMAGED_ARMIES; i++)
    {
      let damagedArmyObj = bodyObj.findObject("damaged_army_" + i)
      if (!::check_obj(damagedArmyObj))
        continue

      if (!dmgArmiesData || !(i in dmgArmiesData))
      {
        damagedArmyObj.show(false)
        continue
      }

      let wwArmyName = dmgArmiesData[i].armyName
      let wwArmy = ::g_ww_logs.logsArmies[wwArmyName]

      let textValue = dmgArmiesData[i].casualties.tostring()
      let textColor = wwArmy.isMySide(::ww_get_player_side()) ?
        WW_LOG_COLORS.BAD_EVENT : WW_LOG_COLORS.GOOD_EVENT

      let armyCasualtiesObj = damagedArmyObj.findObject("army_casualties")
      if (::check_obj(armyCasualtiesObj))
        armyCasualtiesObj.setValue(
          ::loc("worldWar/iconStrike") + ::colorize(textColor, textValue)
        )

      let armyContainerObj = damagedArmyObj.findObject("army_container")
      let armyObj = armyContainerObj.getChild(0)
      fillLogArmyObject(wwArmy.getView(), armyObj)
      damagedArmyObj.show(true)
    }
  }

  function fillLogBattleObject(bodyObj, battleData)
  {
    let battleObj = ::showBtn("battle", battleData != null, bodyObj)
    if (!battleObj || !battleData)
      return

    let wwBattleView = battleData.battleView.battle
    if (wwBattleView)
      setObjParamsById(battleObj, "battle_icon", {
        status = wwBattleView.getStatus(),
        battleId = wwBattleView.getId() })

    let tooltipId = WW_LOG_BATTLE_TOOLTIP.getTooltipId("",
      {currentId = wwBattleView.getId()})
    let tooltipObj = bodyObj.findObject("battle_icon_tooltip")
    if (::check_obj(tooltipObj))
      tooltipObj.tooltipId = tooltipId

    foreach (side in ::g_world_war.getCommonSidesOrder())
    {
      let armyContainerObj = battleObj.findObject("army_side_" + side + "_container")
      if (!::check_obj(armyContainerObj))
        continue

      for (local idx = WW_LOG_BATTLE.MIN_ARMIES_PER_SIDE;
                 idx < WW_LOG_BATTLE.MAX_ARMIES_PER_SIDE; idx++)
        if (idx < armyContainerObj.childrenCount())
          armyContainerObj.getChild(idx).show(false)
    }
    foreach (idx, wwArmy in battleData.armySide1View.army)
      fillLogArmyContainer(wwArmy, "army_side_1", bodyObj, idx, battleData.armySide1View.army.len())
    foreach (idx, wwArmy in battleData.armySide2View.army)
      fillLogArmyContainer(wwArmy, "army_side_2", bodyObj, idx, battleData.armySide2View.army.len())
  }

  function fillLogArmyContainer(wwArmy, armyObjId, bodyObj,
    idx = WW_LOG_BATTLE.DEFAULT_ARMY_INDEX,
    amount = WW_LOG_BATTLE.MIN_ARMIES_PER_SIDE)
  {
    let armyTextObj = ::showBtn(armyObjId, wwArmy != null, bodyObj)
    if (!armyTextObj || !wwArmy)
      return

    armyTextObj.width = amount + "@wwArmySmallIconWidth"
    let armyContainerObj = armyTextObj.findObject(armyObjId + "_container")
    if (!::check_obj(armyContainerObj))
      return
    if (idx >= armyContainerObj.childrenCount())
      return

    let armyObj = armyContainerObj.getChild(idx)
    fillLogArmyObject(wwArmy, armyObj)
  }

  function fillLogArmyObject(wwArmy, armyObj)
  {
    armyObj.show(true)
    armyObj.armyId = wwArmy.getId()
    armyObj.id = wwArmy.getName()
    armyObj.selected = "no"
    let armyIconObj = armyObj.findObject("army_icon")
    armyIconObj.team = wwArmy.getTeamColor()
    armyIconObj.isBelongsToMyClan = wwArmy.isBelongsToMyClan() ? "yes" : "no"
    armyObj.findObject("army_unit_text").setValue(wwArmy.getUnitTypeCustomText())
    armyObj.findObject("army_entrench_icon").show(wwArmy.isEntrenched())
  }

  function getOutsideBlockLogAmount(firstLogId)
  {
    if (!::check_obj(logContainerObj))
      return -1

    for(local i = 1; i < WW_MAX_TOP_LOGS_NUMBER_TO_REMOVE; i++)
      if (logContainerObj.getChild(i).id == firstLogId)
        return i

    return -1
  }

  function removeOutsideBlockLogs(amount)
  {
    if (!::check_obj(logContainerObj))
      return

    for(local i = 0; i < amount; i++)
      guiScene.destroyElement(logContainerObj.getChild(0))
  }

  function addMissingLogs(amount)
  {
    if (!::check_obj(logContainerObj))
      return

    if (!amount)
      return

    local emptyLogsStrToAdd = ""
    for(local i = 0; i < amount; i++)
      emptyLogsStrToAdd += emptyLogChild

    guiScene.appendWithBlk(logContainerObj, emptyLogsStrToAdd, this)
  }

  function onEventWWNewLogsLoaded(params = null)
  {
    if (!::check_obj(logContainerObj))
      return

    isLogPageScrolledDown = false

    if (!::g_ww_logs.filtered.len())
      return

    let lastContainerObj = logContainerObj.getChild(viewLogAmount - 1)
    if (!::check_obj(lastContainerObj))
      return

    let lastFilteredLogId = ::g_ww_logs.loaded[::g_ww_logs.filtered.top()].id
    if (lastContainerObj?.id != lastFilteredLogId)
      return

    let visibleBox = ::GuiBox().setFromDaguiObj(logFrameObj)
    let lastFilteredLogBox = ::GuiBox().setFromDaguiObj(lastContainerObj)
    if (lastFilteredLogBox.isInside(visibleBox))
      isLogPageScrolledDown = true
  }

  function markPreviousLogsAsReaded()
  {
    if (!::g_ww_logs.viewIndex)
      return

    for (local i = ::g_ww_logs.viewIndex - 1; i >= 0; i--)
    {
      if (!(i in ::g_ww_logs.filtered))
        break

      let num = ::g_ww_logs.filtered[i]
      if (::g_ww_logs.loaded[num].isReaded)
        break

      ::g_ww_logs.loaded[num].isReaded = true
    }
  }

  function getScrollTargetId()
  {
    local scrollTargetId = null
    if (!::check_obj(logContainerObj))
      return scrollTargetId

    let visibleBox = ::GuiBox().setFromDaguiObj(logFrameObj)
    for(local i = 0; i < logContainerObj.childrenCount(); i++)
    {
      let logObj = logContainerObj.getChild(i)
      if (!logObj.isVisible())
        break

      let logBox = ::GuiBox().setFromDaguiObj(logObj)
      if (logBox.isInside(visibleBox))
        scrollTargetId = logObj?.id
      else
        if (scrollTargetId)
          break
    }

    return scrollTargetId
  }

  function configScrollPosition(scrollTargetId, isNewOperationEventLog = false)
  {
    if (!::check_obj(logContainerObj))
      return

    if (!logContainerObj.childrenCount())
      return
    if (viewLogAmount <= 0)
      return

    local scrollTargetObj = null
    if (scrollTargetId && !isNewOperationEventLog)
    {
      for(local i = 0; i < logContainerObj.childrenCount(); i++)
        if (logContainerObj.getChild(i).id == scrollTargetId)
        {
          scrollTargetObj = logContainerObj.getChild(i)
          break
        }
    }
    else
      scrollTargetObj = logContainerObj.getChild(viewLogAmount - 1)

    guiScene.performDelayed(this, (@(scrollTargetObj) function () {
      if (::check_obj(scrollTargetObj))
        scrollTargetObj.scrollToView()
    })(scrollTargetObj))
  }

  function configManageBlocks()
  {
    if (!::check_obj(logContainerObj))
      return

    let prevLogsObj = scene.findObject("show_prev_logs")
    if (::check_obj(prevLogsObj))
      prevLogsObj.show(::g_ww_logs.filtered.len())

    if (viewLogAmount > 0)
    {
      let firstLogObj = logContainerObj.getChild(0)
      let prevLogsTextObj = scene.findObject("show_prev_logs_text")
      if (::check_obj(prevLogsTextObj))
        prevLogsTextObj.setValue(firstLogObj.findObject("date_text").getValue())
      let nextLogsTextObj = scene.findObject("show_next_logs_text")
      let lastLogObj = logContainerObj.getChild(viewLogAmount-1)
      if (::check_obj(nextLogsTextObj))
        nextLogsTextObj.setValue(lastLogObj.findObject("date_text").getValue())
    }

    configShowPrevLogsBlock()
    configShowNextLogsBlock()

    let hidedObj = scene.findObject("hidden_logs_text")
    if (!::check_obj(hidedObj))
      return

    let hiddenQuantity = ::g_ww_logs.loaded.len() - ::g_ww_logs.filtered.len()
    hidedObj.setValue(hiddenQuantity ?
      ::loc("worldWar/hided_logs") + ::loc("ui/colon") + hiddenQuantity : "")
  }

  function configShowPrevLogsBlock()
  {
    let prevLogsNestObj = scene.findObject("show_prev_logs_btn_nest")
    if (!::check_obj(prevLogsNestObj))
      return

    prevLogsNestObj.show(::g_ww_logs.lastMark || ::g_ww_logs.viewIndex > 0)
    updatePrevLogsBtn(false)
  }

  function configShowNextLogsBlock(isForcedShow = false)
  {
    let nextLogsObj = scene.findObject("show_next_logs")
    if (::check_obj(nextLogsObj))
      nextLogsObj.show(isForcedShow || ::g_ww_logs.viewIndex + WW_LOG_MAX_DISPLAY_AMOUNT < ::g_ww_logs.filtered.len())
  }

  function onHoverZoneName(obj)
  {
    let zone = obj.getValue()
    if (zone)
      ::ww_mark_zones_as_outlined_by_name([zone])
  }

  function onHoverLostZoneName(obj)
  {
    ::ww_clear_outlined_zones()
  }

  function onHoverArmyItem(obj)
  {
    clearHoverFromLogArmy()
    setArmyObjsHovered(findArmyObjsInLog(obj.id), true)
    markZoneByArmyName(obj.id)
    ::ww_update_hover_army_name(obj.id)
  }

  function onHoverLostArmyItem(obj)
  {
    clearHoverFromLogArmy()
    ::ww_update_hover_army_name("")
    ::ww_clear_outlined_zones()
  }

  function clearHoverFromLogArmy()
  {
    setArmyObjsHovered(findArmyObjsInLog(hoveredArmyName), false)
  }

  function onHoverBattle(obj)
  {
    ::ww_update_hover_battle_id(obj.battleId)
  }

  function onHoverLostBattle(obj)
  {
    ::ww_update_hover_battle_id("")
  }

  function onClickArmy(obj)
  {
    clearSelectFromLogArmy()

    let wwArmy = ::getTblValue(obj.armyId, ::g_ww_logs.logsArmies)
    if (wwArmy)
      ::ww_event("ShowLogArmy", { wwArmy = wwArmy })
  }

  function onEventWWSelectLogArmyByName(params = {})
  {
    if (::getTblValue("name", params))
      setArmyObjsSelected(findArmyObjsInLog(params.name), true)
  }

  function onEventWWClearSelectFromLogArmy(params = {})
  {
    clearSelectFromLogArmy()
  }

  function clearSelectFromLogArmy()
  {
    setArmyObjsSelected(findArmyObjsInLog(selectedArmyName), false)
  }

  function markZoneByArmyName(armyName)
  {
    let wwArmy = ::g_world_war.getArmyByName(armyName)
    if (!wwArmy)
      return

    let wwArmyPosition = wwArmy.getPosition()
    if (!wwArmyPosition)
      return

    let wwArmyZoneName = ::ww_get_zone_name(::ww_get_zone_idx_world(wwArmyPosition))
    ::ww_mark_zones_as_outlined_by_name([wwArmyZoneName])
  }

  function findArmyObjsInLog(armyName)
  {
    if (::u.isEmpty(armyName))
      return []

    let armyObjects = []
    for(local i = 0; i < logContainerObj.childrenCount(); i++)
    {
      let logObj = logContainerObj.getChild(i)
      if (!::check_obj(logObj))
        continue

      if (!logObj.isVisible())
        break

      let armyObj = logObj.findObject(armyName)
      if (::check_obj(armyObj))
        armyObjects.append(armyObj)
    }

    return armyObjects
  }

  function setArmyObjsHovered(armyObjects, hovered)
  {
    if (!armyObjects.len())
      return

    hoveredArmyName = hovered ? armyObjects[0].id : ""
    foreach (armyObj in armyObjects)
      armyObj.isForceHovered = hovered ? "yes" : "no"
  }

  function setArmyObjsSelected(armyObjects, selected)
  {
    if (!armyObjects.len())
      return

    selectedArmyName = selected ? armyObjects[0].id : ""
    foreach (armyObj in armyObjects)
      armyObj.selected = selected ? "yes" : "no"
  }

  function onClickBattle(obj)
  {
    let battleId = obj.battleId
    let battle = ::g_world_war.getBattleById(battleId)
    if (battle.isValid())
    {
      ::ww_event("MapSelectedBattle", { battle = battle })
      return
    }

    let logBlk = ::g_ww_logs.logsBattles?[battleId].logBlk
    ::gui_handlers.WwBattleResults.open(::WwBattleResults(logBlk))
  }

  function onClickShowFirstLogs(obj)
  {
    ::g_ww_logs.viewIndex = ::max(::g_ww_logs.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT, 0)
    fillLogBlock(true)
  }

  function onClickShowPrevLogs(obj)
  {
    if (::g_ww_logs.viewIndex > 0)
    {
      ::g_ww_logs.viewIndex = ::max(::g_ww_logs.viewIndex - WW_LOG_MAX_LOAD_AMOUNT, 0)
      fillLogBlock()
      return
    }
    ::g_ww_logs.requestNewLogs(WW_LOG_MAX_LOAD_AMOUNT, true, this)
  }

  function updatePrevLogsBtn(isLogsLoading = false)
  {
    let prevLogsBtnObj = scene.findObject("show_prev_logs_btn")
    if (!::check_obj(prevLogsBtnObj))
      return

    let waitAnimObj = prevLogsBtnObj.findObject("show_prev_logs_btn_wait_anim")
    if (::check_obj(waitAnimObj))
      waitAnimObj.show(isLogsLoading)

    prevLogsBtnObj.hideText = isLogsLoading ? "yes" : "no"
    prevLogsBtnObj.enable(!isLogsLoading)
  }

  function onEventWWLogsLoadStatusChanged(params)
  {
    updatePrevLogsBtn(params.isLogsLoading)
  }

  function onClickShowNextLogs(obj)
  {
    ::g_ww_logs.viewIndex += WW_LOG_MAX_LOAD_AMOUNT
    if (::g_ww_logs.viewIndex > ::g_ww_logs.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT)
      ::g_ww_logs.viewIndex = ::max(::g_ww_logs.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT, 0)

    fillLogBlock()
  }

  function onShowOperationLogFilters(obj)
  {
    foreach(renderData in ::g_ww_logs.logCategories)
      renderData.selected = ::g_ww_logs.filter[renderData.value]

    ::gui_start_multi_select_menu({
      list = ::g_ww_logs.logCategories
      onChangeValueCb = onApplyOperationLogFilters.bindenv(this)
      align = "bottom"
      alignObj = scene.findObject("ww_log_filters")
      sndSwitchOn = "check"
      sndSwitchOff = "uncheck"
    })
  }

  function onApplyOperationLogFilters(values)
  {
    foreach(renderData in ::g_ww_logs.logCategories)
    {
      let category = renderData.value
      let enable = ::isInArray(category, values)
      if (::g_ww_logs.filter[category] == enable)
        continue

      ::g_ww_logs.filter[category] = enable
      ::g_ww_logs.applyLogsFilter()
      ::g_ww_logs.viewIndex = ::max(::g_ww_logs.filtered.len() - 1, 0)

      if (!::g_ww_logs.loaded.len())
        return

      let logNumber = ::g_ww_logs.loaded.len() - 1
      local scrollTargetId = null
      local logsAmount = 0
      for (local i = ::g_ww_logs.filtered.len() - 1; i >= 0; i--)
      {
        ::g_ww_logs.viewIndex = i
        if (::g_ww_logs.filtered[i] <= logNumber)
        {
          logsAmount++
          if (!scrollTargetId)
            scrollTargetId = ::g_ww_logs.loaded[::g_ww_logs.filtered[i]].id.tostring()
        }
        if (logsAmount >= WW_LOG_MAX_DISPLAY_AMOUNT)
          break
      }

      fillLogBlock(true, scrollTargetId)
      break
    }
  }
}
