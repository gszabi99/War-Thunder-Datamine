from "%scripts/dagui_natives.nut" import ww_get_selected_armies_names, ww_update_hover_battle_id, ww_get_zone_idx_world, ww_mark_zones_as_outlined_by_name
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { getWwTooltipType } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { wwGetPlayerSide, wwGetZoneName, wwClearOutlinedZones, wwUpdateHoverArmyName } = require("worldwar")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { WwBattleResults } = require("%scripts/worldWar/inOperation/model/wwBattleResults.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let WwOperationLogView = require("%scripts/worldWar/inOperation/view/wwOperationLogView.nut")
let { getWWLogsData, applyWWLogsFilter, saveLastReadWWLogMark,
  getUnreadedWWLogsNumber, requestNewWWLogs } = require("%scripts/worldWar/inOperation/model/wwOperationLog.nut")
let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")
let { GuiBox } = require("%scripts/guiBox.nut")
let { getArmyByName } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")

const WW_MAX_TOP_LOGS_NUMBER_TO_REMOVE = 5
const WW_LOG_MAX_DISPLAY_AMOUNT = 40

gui_handlers.WwOperationLog <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneTplName = null
  sceneBlkName = "%gui/worldWar/worldWarOperationLogInfo"
  emptyLogBlockBlk = "%gui/worldWar/wwOperationLogRow.blk"
  prevLogDate = ""
  viewLogAmount = 0
  isLogPageScrolledDown = false

  logFrameObj = null
  logContainerObj = null

  selectedArmyName = ""
  hoveredArmyName = ""

  wwLogsData = null

  function getSceneTplView() {
    return {}
  }

  function getSceneTplContainerObj() {
    return this.scene
  }

  function isValid() {
    return checkObj(this.scene) && checkObj(this.logFrameObj)
  }

  function initScreen() {
    this.logFrameObj = this.scene.findObject("ww_operation_log_frame")
    this.logContainerObj = this.scene.findObject("ww_operation_log")

    this.prevLogDate = ""
    this.wwLogsData = getWWLogsData()
    applyWWLogsFilter()
    this.fillLogBlock()
    saveLastReadWWLogMark()
  }

  function onEventWWNewLogsAdded(params = {}) {
    let isLogMarkUsed = getTblValue("isLogMarkUsed", params, false)
    if (!isLogMarkUsed && !this.isLogPageScrolledDown) {
      this.configShowNextLogsBlock({ isForcedShow = true })
      return
    }

    if (isLogMarkUsed)
      this.wwLogsData.viewIndex = 0
    else if (this.isLogPageScrolledDown)
      this.wwLogsData.viewIndex = max(this.wwLogsData.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT, 0)

    this.fillLogBlock(false, null, !isLogMarkUsed && this.isLogPageScrolledDown)
  }

  function onEventWWNoLogsAdded(_params = {}) {
    this.configManageBlocks()
  }

  function fillLogBlock(scrollDefined = false, scrollId = null, isNewOperationEventLog = false) {
    if (!checkObj(this.logContainerObj))
      return

    let emptyTextObj = this.scene.findObject("ww_operation_empty_log")
    if (checkObj(emptyTextObj))
      emptyTextObj.show(!this.wwLogsData.filtered.len())

    if (isNewOperationEventLog && this.wwLogsData.viewIndex in this.wwLogsData.filtered) {
      let firstLog = this.wwLogsData.loaded[this.wwLogsData.filtered[this.wwLogsData.viewIndex]]
      let logAmountToDestroy = this.getOutsideBlockLogAmount(firstLog.id)
      this.removeOutsideBlockLogs(logAmountToDestroy)
      this.addMissingLogs(logAmountToDestroy)
    }

    let scrollTargetId = scrollDefined ? scrollId : this.getScrollTargetId()
    this.markPreviousLogsAsReaded()
    this.guiScene.setUpdatesEnabled(false, false)
    this.viewLogAmount = 0
    for (local i = 0; i < min(this.wwLogsData.loaded.len(), WW_LOG_MAX_DISPLAY_AMOUNT); i++) {
      if (this.logContainerObj.childrenCount() < i + 1)
        this.guiScene.createElementByObject(this.logContainerObj, this.emptyLogBlockBlk, "tdiv", this)
      let logObj = this.logContainerObj.getChild(i)
      let logIdx = i + this.wwLogsData.viewIndex
      if (!(logIdx in this.wwLogsData.filtered)) {
        logObj.show(false)
        continue
      }

      let num = this.wwLogsData.filtered[logIdx]
      let logO = this.wwLogsData.loaded[num]
      logO.isReaded = true

      let logView = WwOperationLogView(this.wwLogsData.logsViews[logO.id])
      logView.setPrevLogDateValue(this.prevLogDate)
      logView.setIsFirstRowValue(logIdx == this.wwLogsData.viewIndex)
      this.fillLogObject(logObj, logView)
      this.prevLogDate = logView.getDate()

      this.viewLogAmount++
    }

    this.logContainerObj.getChild(0).scrollToView()
    this.guiScene.setUpdatesEnabled(true, true)
    this.configManageBlocks()
    this.configScrollPosition(scrollTargetId, isNewOperationEventLog)

    if (!this.selectedArmyName.len()) {
      let selectedArmies = ww_get_selected_armies_names()
      if (selectedArmies.len())
        this.selectedArmyName = selectedArmies[0]
    }
    this.setArmyObjsSelected(this.findArmyObjsInLog(this.selectedArmyName), true)

    wwEvent("NewLogsDisplayed", { amount = getUnreadedWWLogsNumber() })
  }

  function setObjParamsById(objNest, id, paramsToSet) {
    let obj = objNest.findObject(id)
    if (!checkObj(obj))
      return

    foreach (name, value in paramsToSet)
      if (name == "text")
        obj.setValue(value)
      else
        obj[name] = value
  }

  function fillLogObject(obj, logView) {
    obj.show(true)
    let logId = logView.getId()
    if (obj?.id == logId)
      return

    obj.id = logId
    obj.findObject("date").show(!logView.isFirst() && logView.showDate())

    foreach (blockId, blockData in logView.getBasicInfoTable())
      this.setObjParamsById(obj, blockId, blockData)

    let bodyObj = obj.findObject("log_body")
    if (!checkObj(bodyObj))
      return

    let armyData = logView.getArmyData()
    this.setObjParamsById(bodyObj, "log_text", logView.getTextInfoTable())
    this.fillLogArmyContainer(armyData ? armyData.army[0] : null, "army", bodyObj)
    this.fillLogBattleObject(bodyObj, logView.getBattleData())
    this.fillLogDamagedArmiesObject(bodyObj, logView.getDmgArmiesData())
  }

  function fillLogDamagedArmiesObject(bodyObj, dmgArmiesData) {
    for (local i = 0; i < WW_LOG_BATTLE.MAX_DAMAGED_ARMIES; i++) {
      let damagedArmyObj = bodyObj.findObject($"damaged_army_{i}")
      if (!checkObj(damagedArmyObj))
        continue

      if (!dmgArmiesData || !(i in dmgArmiesData)) {
        damagedArmyObj.show(false)
        continue
      }

      let wwArmyName = dmgArmiesData[i].armyName
      let wwArmy = this.wwLogsData.logsArmies[wwArmyName]

      let textValue = dmgArmiesData[i].casualties.tostring()
      let textColor = wwArmy.isMySide(wwGetPlayerSide()) ?
        WW_LOG_COLORS.BAD_EVENT : WW_LOG_COLORS.GOOD_EVENT

      let armyCasualtiesObj = damagedArmyObj.findObject("army_casualties")
      if (checkObj(armyCasualtiesObj))
        armyCasualtiesObj.setValue(
          $"{loc("worldWar/iconStrike")}{colorize(textColor, textValue)}"
        )

      let armyContainerObj = damagedArmyObj.findObject("army_container")
      let armyObj = armyContainerObj.getChild(0)
      this.fillLogArmyObject(wwArmy.getView(), armyObj)
      damagedArmyObj.show(true)
    }
  }

  function fillLogBattleObject(bodyObj, battleData) {
    let battleObj = showObjById("battle", battleData != null, bodyObj)
    if (!battleObj || !battleData)
      return

    let wwBattleView = battleData.battleView.battle
    if (wwBattleView)
      this.setObjParamsById(battleObj, "battle_icon", {
        status = wwBattleView.getStatus(),
        battleId = wwBattleView.getId() })

    let tooltipId = getWwTooltipType("WW_LOG_BATTLE_TOOLTIP").getTooltipId("",
      { currentId = wwBattleView.getId() })
    let tooltipObj = bodyObj.findObject("battle_icon_tooltip")
    if (checkObj(tooltipObj))
      tooltipObj.tooltipId = tooltipId

    foreach (side in g_world_war.getCommonSidesOrder()) {
      let armyContainerObj = battleObj.findObject($"army_side_{side}_container")
      if (!checkObj(armyContainerObj))
        continue

      for (local idx = WW_LOG_BATTLE.MIN_ARMIES_PER_SIDE;
                 idx < WW_LOG_BATTLE.MAX_ARMIES_PER_SIDE; idx++)
        if (idx < armyContainerObj.childrenCount())
          armyContainerObj.getChild(idx).show(false)
    }
    foreach (idx, wwArmy in battleData.armySide1View.army)
      this.fillLogArmyContainer(wwArmy, "army_side_1", bodyObj, idx, battleData.armySide1View.army.len())
    foreach (idx, wwArmy in battleData.armySide2View.army)
      this.fillLogArmyContainer(wwArmy, "army_side_2", bodyObj, idx, battleData.armySide2View.army.len())
  }

  function fillLogArmyContainer(wwArmy, armyObjId, bodyObj,
    idx = WW_LOG_BATTLE.DEFAULT_ARMY_INDEX,
    amount = WW_LOG_BATTLE.MIN_ARMIES_PER_SIDE) {
    let armyTextObj = showObjById(armyObjId, wwArmy != null, bodyObj)
    if (!armyTextObj || !wwArmy)
      return

    armyTextObj.width = $"{amount}@wwArmySmallIconWidth"
    let armyContainerObj = armyTextObj.findObject($"{armyObjId}_container")
    if (!checkObj(armyContainerObj))
      return
    if (idx >= armyContainerObj.childrenCount())
      return

    let armyObj = armyContainerObj.getChild(idx)
    this.fillLogArmyObject(wwArmy, armyObj)
  }

  function fillLogArmyObject(wwArmy, armyObj) {
    armyObj.show(true)
    armyObj.armyId = wwArmy.getId()
    armyObj.id = wwArmy.getName()
    armyObj.selected = "no"
    let armyIconObj = armyObj.findObject("army_icon")
    armyIconObj.team = wwArmy.getTeamColor()
    armyIconObj.isBelongsToMyClan = wwArmy.isBelongsToMyClan() ? "yes" : "no"
    armyObj.findObject("army_unit_icon")["background-image"] = wwArmy.getUnitTypeIcon()
    armyObj.findObject("army_entrench_icon").show(wwArmy.isEntrenched())
  }

  function getOutsideBlockLogAmount(firstLogId) {
    if (!checkObj(this.logContainerObj))
      return -1

    for (local i = 1; i < WW_MAX_TOP_LOGS_NUMBER_TO_REMOVE; i++)
      if (this.logContainerObj.childrenCount() > i && this.logContainerObj.getChild(i).id == firstLogId)
        return i

    return -1
  }

  function removeOutsideBlockLogs(amount) {
    if (!checkObj(this.logContainerObj))
      return

    for (local i = 0; i < amount; i++)
      this.guiScene.destroyElement(this.logContainerObj.getChild(0))
  }

  function addMissingLogs(amount) {
    if (!checkObj(this.logContainerObj))
      return

    if (!amount)
      return

    this.guiScene.createMultiElementsByObject(this.logContainerObj, this.emptyLogBlockBlk, "tdiv", amount, this)
  }

  function onEventWWNewLogsLoaded(_params = null) {
    if (!checkObj(this.logContainerObj))
      return

    this.isLogPageScrolledDown = false

    if (!this.wwLogsData.filtered.len())
      return

    let lastContainerObj = this.logContainerObj.getChild(this.viewLogAmount - 1)
    if (!checkObj(lastContainerObj))
      return

    let lastFilteredLogId = this.wwLogsData.loaded[this.wwLogsData.filtered.top()].id
    if (lastContainerObj?.id != lastFilteredLogId)
      return

    let visibleBox = GuiBox().setFromDaguiObj(this.logFrameObj)
    let lastFilteredLogBox = GuiBox().setFromDaguiObj(lastContainerObj)
    if (lastFilteredLogBox.isInside(visibleBox))
      this.isLogPageScrolledDown = true
  }

  function markPreviousLogsAsReaded() {
    if (!this.wwLogsData.viewIndex)
      return

    for (local i = this.wwLogsData.viewIndex - 1; i >= 0; i--) {
      if (!(i in this.wwLogsData.filtered))
        break

      let num = this.wwLogsData.filtered[i]
      if (this.wwLogsData.loaded[num].isReaded)
        break

      this.wwLogsData.loaded[num].isReaded = true
    }
  }

  function getScrollTargetId() {
    local scrollTargetId = null
    if (!checkObj(this.logContainerObj))
      return scrollTargetId

    let visibleBox = GuiBox().setFromDaguiObj(this.logFrameObj)
    for (local i = 0; i < this.logContainerObj.childrenCount(); i++) {
      let logObj = this.logContainerObj.getChild(i)
      if (!logObj.isVisible())
        break

      let logBox = GuiBox().setFromDaguiObj(logObj)
      if (logBox.isInside(visibleBox))
        scrollTargetId = logObj?.id
      else if (scrollTargetId)
          break
    }

    return scrollTargetId
  }

  function configScrollPosition(scrollTargetId, isNewOperationEventLog = false) {
    if (!checkObj(this.logContainerObj))
      return

    if (!this.logContainerObj.childrenCount())
      return
    if (this.viewLogAmount <= 0)
      return

    local scrollTargetObj = null
    if (scrollTargetId && !isNewOperationEventLog) {
      for (local i = 0; i < this.logContainerObj.childrenCount(); i++)
        if (this.logContainerObj.getChild(i).id == scrollTargetId) {
          scrollTargetObj = this.logContainerObj.getChild(i)
          break
        }
    }
    else
      scrollTargetObj = this.logContainerObj.getChild(this.viewLogAmount - 1)

    this.guiScene.performDelayed(this, function () {
      if (checkObj(scrollTargetObj))
        scrollTargetObj.scrollToView()
    })
  }

  function configManageBlocks() {
    if (!checkObj(this.logContainerObj))
      return

    let prevLogsObj = this.scene.findObject("show_prev_logs")
    if (checkObj(prevLogsObj))
      prevLogsObj.show(this.wwLogsData.filtered.len())

    if (this.viewLogAmount > 0) {
      let firstLogObj = this.logContainerObj.getChild(0)
      let prevLogsTextObj = this.scene.findObject("show_prev_logs_text")
      if (checkObj(prevLogsTextObj))
        prevLogsTextObj.setValue(firstLogObj.findObject("date_text").getValue())
      let nextLogsTextObj = this.scene.findObject("show_next_logs_text")
      let lastLogObj = this.logContainerObj.getChild(this.viewLogAmount - 1)
      if (checkObj(nextLogsTextObj))
        nextLogsTextObj.setValue(lastLogObj.findObject("date_text").getValue())
    }

    this.configShowPrevLogsBlock()
    this.configShowNextLogsBlock()

    let hidedObj = this.scene.findObject("hidden_logs_text")
    if (!checkObj(hidedObj))
      return

    let hiddenQuantity = this.wwLogsData.loaded.len() - this.wwLogsData.filtered.len()
    hidedObj.setValue(
      hiddenQuantity ? loc("ui/colon").concat(loc("worldWar/hided_logs"), hiddenQuantity) : "")
  }

  function configShowPrevLogsBlock() {
    let prevLogsNestObj = this.scene.findObject("show_prev_logs_btn_nest")
    if (!checkObj(prevLogsNestObj))
      return

    prevLogsNestObj.show(this.wwLogsData.lastMark != "" || this.wwLogsData.viewIndex > 0)
    this.updatePrevLogsBtn(false)
  }

  function configShowNextLogsBlock(isForcedShow = false) {
    let nextLogsObj = this.scene.findObject("show_next_logs")
    if (checkObj(nextLogsObj))
      nextLogsObj.show(isForcedShow || this.wwLogsData.viewIndex + WW_LOG_MAX_DISPLAY_AMOUNT < this.wwLogsData.filtered.len())
  }

  function onHoverZoneName(obj) {
    let zone = obj.getValue()
    if (zone)
      ww_mark_zones_as_outlined_by_name([zone])
  }

  function onHoverLostZoneName(_obj) {
    wwClearOutlinedZones()
  }

  function onHoverArmyItem(obj) {
    this.clearHoverFromLogArmy()
    this.setArmyObjsHovered(this.findArmyObjsInLog(obj.id), true)
    this.markZoneByArmyName(obj.id)
    wwUpdateHoverArmyName(obj.id)
  }

  function onHoverLostArmyItem(_obj) {
    this.clearHoverFromLogArmy()
    wwUpdateHoverArmyName("")
    wwClearOutlinedZones()
  }

  function clearHoverFromLogArmy() {
    this.setArmyObjsHovered(this.findArmyObjsInLog(this.hoveredArmyName), false)
  }

  function onHoverBattle(obj) {
    ww_update_hover_battle_id(obj.battleId)
  }

  function onHoverLostBattle(_obj) {
    ww_update_hover_battle_id("")
  }

  function onClickArmy(obj) {
    this.clearSelectFromLogArmy()

    let wwArmy = getTblValue(obj.armyId, this.wwLogsData.logsArmies)
    if (wwArmy)
      wwEvent("ShowLogArmy", { wwArmy = wwArmy })
  }

  function onEventWWSelectLogArmyByName(params = {}) {
    if (getTblValue("name", params))
      this.setArmyObjsSelected(this.findArmyObjsInLog(params.name), true)
  }

  function onEventWWClearSelectFromLogArmy(_params = {}) {
    this.clearSelectFromLogArmy()
  }

  function clearSelectFromLogArmy() {
    this.setArmyObjsSelected(this.findArmyObjsInLog(this.selectedArmyName), false)
  }

  function markZoneByArmyName(armyName) {
    let wwArmy = getArmyByName(armyName)
    if (!wwArmy)
      return

    let wwArmyPosition = wwArmy.getPosition()
    if (!wwArmyPosition)
      return

    let wwArmyZoneName = wwGetZoneName(ww_get_zone_idx_world(wwArmyPosition))
    ww_mark_zones_as_outlined_by_name([wwArmyZoneName])
  }

  function findArmyObjsInLog(armyName) {
    if (u.isEmpty(armyName))
      return []

    let armyObjects = []
    for (local i = 0; i < this.logContainerObj.childrenCount(); i++) {
      let logObj = this.logContainerObj.getChild(i)
      if (!checkObj(logObj))
        continue

      if (!logObj.isVisible())
        break

      let armyObj = logObj.findObject(armyName)
      if (checkObj(armyObj))
        armyObjects.append(armyObj)
    }

    return armyObjects
  }

  function setArmyObjsHovered(armyObjects, hovered) {
    if (!armyObjects.len())
      return

    this.hoveredArmyName = hovered ? armyObjects[0].id : ""
    foreach (armyObj in armyObjects)
      armyObj.isForceHovered = hovered ? "yes" : "no"
  }

  function setArmyObjsSelected(armyObjects, selected) {
    if (!armyObjects.len())
      return

    this.selectedArmyName = selected ? armyObjects[0].id : ""
    foreach (armyObj in armyObjects)
      armyObj.selected = selected ? "yes" : "no"
  }

  function onClickBattle(obj) {
    let battleId = obj.battleId
    let battle = g_world_war.getBattleById(battleId)
    if (battle.isValid()) {
      wwEvent("MapSelectedBattle", { battle = battle })
      return
    }

    let logBlk = this.wwLogsData.logsBattles?[battleId].logBlk
    gui_handlers.WwBattleResults.open(WwBattleResults(logBlk))
  }

  function onClickShowFirstLogs(_obj) {
    this.wwLogsData.viewIndex = max(this.wwLogsData.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT, 0)
    this.fillLogBlock(true)
  }

  function onClickShowPrevLogs(_obj) {
    if (this.wwLogsData.viewIndex > 0) {
      this.wwLogsData.viewIndex = max(this.wwLogsData.viewIndex - WW_LOG_MAX_LOAD_AMOUNT, 0)
      this.fillLogBlock()
      return
    }
    requestNewWWLogs(WW_LOG_MAX_LOAD_AMOUNT, true, this)
  }

  function updatePrevLogsBtn(isLogsLoading = false) {
    let prevLogsBtnObj = this.scene.findObject("show_prev_logs_btn")
    if (!checkObj(prevLogsBtnObj))
      return

    let waitAnimObj = prevLogsBtnObj.findObject("show_prev_logs_btn_wait_anim")
    if (checkObj(waitAnimObj))
      waitAnimObj.show(isLogsLoading)

    prevLogsBtnObj.hideText = isLogsLoading ? "yes" : "no"
    prevLogsBtnObj.enable(!isLogsLoading)
  }

  function onEventWWLogsLoadStatusChanged(params) {
    this.updatePrevLogsBtn(params.isLogsLoading)
  }

  function onClickShowNextLogs(_obj) {
    this.wwLogsData.viewIndex += WW_LOG_MAX_LOAD_AMOUNT
    if (this.wwLogsData.viewIndex > this.wwLogsData.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT)
      this.wwLogsData.viewIndex = max(this.wwLogsData.filtered.len() - WW_LOG_MAX_DISPLAY_AMOUNT, 0)

    this.fillLogBlock()
  }

  function onShowOperationLogFilters(_obj) {
    foreach (renderData in this.wwLogsData.logCategories)
      renderData.selected = this.wwLogsData.filter[renderData.value]

    loadHandler(gui_handlers.MultiSelectMenu, {
      list = this.wwLogsData.logCategories
      onChangeValueCb = this.onApplyOperationLogFilters.bindenv(this)
      align = "bottom"
      alignObj = this.scene.findObject("ww_log_filters")
      sndSwitchOn = "check"
      sndSwitchOff = "uncheck"
    })
  }

  function onApplyOperationLogFilters(values) {
    foreach (renderData in this.wwLogsData.logCategories) {
      let category = renderData.value
      let enable = isInArray(category, values)
      if (this.wwLogsData.filter[category] == enable)
        continue

      this.wwLogsData.filter[category] = enable
      applyWWLogsFilter()
      this.wwLogsData.viewIndex = max(this.wwLogsData.filtered.len() - 1, 0)

      if (!this.wwLogsData.loaded.len())
        return

      let logNumber = this.wwLogsData.loaded.len() - 1
      local scrollTargetId = null
      local logsAmount = 0
      for (local i = this.wwLogsData.filtered.len() - 1; i >= 0; i--) {
        this.wwLogsData.viewIndex = i
        if (this.wwLogsData.filtered[i] <= logNumber) {
          logsAmount++
          if (!scrollTargetId)
            scrollTargetId = this.wwLogsData.loaded[this.wwLogsData.filtered[i]].id.tostring()
        }
        if (logsAmount >= WW_LOG_MAX_DISPLAY_AMOUNT)
          break
      }

      this.fillLogBlock(true, scrollTargetId)
      break
    }
  }
}
