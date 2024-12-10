from "%scripts/dagui_natives.nut" import ww_side_val_to_name, ww_mark_zones_as_outlined_by_name
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { Point2 } = require("dagor.math")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let DataBlock  = require("DataBlock")

let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { startsWith } = require("%sqstd/string.nut")
let { wwGetOperationId, wwGetOperationWinner, wwClearOutlinedZones } = require("worldwar")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { WwObjectiveView } =  require("%scripts/worldWar/inOperation/view/wwObjectiveView.nut")
let { isOperationFinished } = require("%appGlobals/worldWar/wwOperationState.nut")

gui_handlers.wwObjective <- class (BaseGuiHandler) {
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/worldWarObjectivesInfo.tpl"
  sceneBlkName = null
  objectiveItemTpl = "%gui/worldWar/worldWarObjectiveItem.tpl"
  singleOperationTplName = "%gui/worldWar/operationString.tpl"

  staticBlk = null
  dynamicBlk = null

  timersArray = null

  side = SIDE_NONE
  needShowOperationDesc = true
  reqFullMissionObjectsButton = true
  restrictShownObjectives = false
  hasObjectiveDesc = false

  function getSceneTplView() {
    return {
      reqFullMissionObjectsButton = this.reqFullMissionObjectsButton
    }
  }

  function getSceneTplContainerObj() {
    return this.scene
  }

  function isValid() {
    return checkObj(this.scene) && checkObj(this.scene.findObject("ww_mission_objectives"))
  }

  function initScreen() {
    this.update()
    this.checkTimers()
  }

  function update() {
    let placeObj = this.scene.findObject("ww_mission_objectives")
    if (!checkObj(placeObj))
      return

    this.updateObjectivesData()

    let curOperation = getOperationById(wwGetOperationId())
    let unseenIcon = curOperation
      ? bhvUnseen.makeConfigStr(SEEN.WW_MAPS_OBJECTIVE, curOperation.getMapId()) : null
    let objectivesList = this.getObjectivesList(this.getObjectivesCount(false))
    let view = {
      unseenIcon = unseenIcon
      objectiveBlock = this.getObjectiveBlocksArray()
      reqFullMissionObjectsButton = this.reqFullMissionObjectsButton
      hiddenObjectives = max(objectivesList.primaryCount - this.getShowMaxObjectivesCount().x, 0)
      hasObjectiveDesc = this.hasObjectiveDesc
    }
    let data = handyman.renderCached(this.objectiveItemTpl, view)
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function checkTimers() {
    this.timersArray = []
    foreach (_id, dataBlk in this.staticBlk) {
      let statusBlk = this.getStatusBlock(dataBlk)
      let oType = ::g_ww_objective_type.getTypeByTypeName(dataBlk?.type)
      let handler = this
      foreach (param, func in oType.timersArrayByParamName)
        this.timersArray.extend(func(handler, this.scene, param, dataBlk, statusBlk, oType, this.side))
    }
  }

  function updateObjectivesData() {
    let objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    this.staticBlk = u.copy(objectivesBlk?.data) || DataBlock()
    this.dynamicBlk = u.copy(objectivesBlk?.status) || DataBlock()
  }

  function canShowObjective(objBlock, checkType = true, isForceVisible = false) {
    if (::g_world_war.isDebugModeEnabled())
      return true

    if (this.needShowOperationDesc && !isForceVisible && !objBlock?.showInOperationDesc)
      return false

    if (checkType) {
      let oType = ::g_ww_objective_type.getTypeByTypeName(objBlock?.type)
      let isDefender = oType.isDefender(objBlock, ww_side_val_to_name(this.side))

      if (objBlock?.showOnlyForDefenders)
        return isDefender

      if (objBlock?.showOnlyForAttackers)
        return !isDefender

      if (objBlock?.type == ::g_ww_objective_type.OT_DONT_AFK.typeName)
        return false
    }

    return true
  }

  function getShowMaxObjectivesCount() {
    let winner = wwGetOperationWinner()
    if (this.restrictShownObjectives && winner != SIDE_NONE)
      return Point2(1, 0)

    let objectivesCount = this.getObjectivesCount()

    if (!this.restrictShownObjectives || ::g_world_war.isDebugModeEnabled())
      return objectivesCount

    let guiScene = this.scene.getScene()

    let panelObj = guiScene["content_block_1"]
    let holderObj = panelObj.getParent()

    let busyHeight = holderObj.findObject("operation_info").getSize()[1]

    let content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)
    let blockHeight = content1BlockHeight - busyHeight

    local headers = 0
    if (objectivesCount.x > 0)
      headers++
    if (objectivesCount.y > 0)
      headers++
    let reservedHeight = guiScene.calcString($"1@frameHeaderHeight + {headers}@objectiveBlockHeaderHeight", null)

    let availObjectivesHeight = blockHeight - reservedHeight

    let singleObjectiveHeight = guiScene.calcString("1@objectiveHeight", null)
    let allowObjectives = availObjectivesHeight / singleObjectiveHeight
    let res = Point2(0, 0)
    res.x = max(1, min(objectivesCount.x, allowObjectives))
    if (allowObjectives > res.x)
      res.y = max(1, min(objectivesCount.y, allowObjectives))
    return res
  }

  function getObjectivesCount(checkType = true) {
    let objectivesCount = Point2(0, 0)
    foreach (block in this.staticBlk)
      if (this.canShowObjective(block, checkType)) {
        if (block?.mainObjective)
          objectivesCount.x++
        else
          objectivesCount.y++
      }

    return objectivesCount
  }

  function onEventWWAFKTimerStop(_params) {
    this.recalculateTopPosition()
  }

  function onEventWWAFKTimerStart(params) {
    if (params?.needResize ?? false)
      this.setTopPosition(0)
    else
      this.recalculateTopPosition()
  }

  function setTopPosition(value) {
    if (!this.restrictShownObjectives)
      return
    this.scene.getScene()["content_block_1"].top = value
  }

  function recalculateTopPosition() {
    if (!this.restrictShownObjectives)
      return

    let objectivesCount = this.getShowMaxObjectivesCount()
    let guiScene = this.scene.getScene()
    let content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)

    let busyHeight = guiScene["operation_info"].getSize()[1]

    local headers = 0
    if (objectivesCount.x > 0)
      headers++
    if (objectivesCount.y > 0)
      headers++

    let reservedHeight = guiScene.calcString(
      $"1@frameHeaderHeight + {headers}@objectiveBlockHeaderHeight", null)
    let objectivesHeight = guiScene.calcString(
      $"{objectivesCount.x + objectivesCount.y}@objectiveHeight", null)

    this.setTopPosition(content1BlockHeight - busyHeight - reservedHeight - objectivesHeight)
  }

  function getObjectiveBlocksArray() {
    this.recalculateTopPosition()
    let availableObjectiveSlots = this.getShowMaxObjectivesCount()
    let objectivesList = this.getObjectivesList(availableObjectiveSlots)

    local countryIcon = ""
    let groups = ::g_world_war.getArmyGroupsBySide(this.side)
    if (groups.len() > 0)
      countryIcon = groups[0].getCountryIcon()

    let objectiveBlocks = []
    foreach (name in ["primary", "secondary"]) {
      let arr = objectivesList[name]
      objectiveBlocks.append({
          id = name,
          isPrimary = name == "primary"
          countryIcon = countryIcon
          hide = arr.len() == 0
          objectives = this.getObjectiveViewsArray(arr)
        })
    }

    return objectiveBlocks
  }

  function getAFKStatusBlock() {
    if (!isOperationFinished())
      return null
    foreach (idx, inst in this.staticBlk)
      if (startsWith(idx, "dont_afk") && this.getStatusBlock(inst)?.winner)
        return inst
    return null
  }

  function getObjectivesList(availableObjectiveSlots, checkType = true) {
    local list = {
      primary = []
      secondary = []
      primaryCount = 0
    }

    let statusBlk = this.getAFKStatusBlock()
    list.primary = statusBlk ? [statusBlk] : []
    list.primaryCount = list.primary.len()
    if (list.primaryCount)
      return list

    let usedObjectiveSlots = Point2(0, 0)
    for (local i = 0; i < this.staticBlk.blockCount(); i++) {
      let objBlock = this.staticBlk.getBlock(i)
      if (!this.canShowObjective(objBlock, checkType, true))
        continue

      list.primaryCount += objBlock?.mainObjective ? 1 : 0

      if (usedObjectiveSlots.x >= availableObjectiveSlots.x
        && usedObjectiveSlots.y >= availableObjectiveSlots.y)
        continue

      if (!this.canShowObjective(objBlock, checkType))
        continue

      objBlock.id <- objBlock.getBlockName()

      if (objBlock?.mainObjective && usedObjectiveSlots.x < availableObjectiveSlots.x) {
        usedObjectiveSlots.x++
        list.primary.append(objBlock)
      }
      else if (usedObjectiveSlots.y < availableObjectiveSlots.y) {
        usedObjectiveSlots.y++
        list.secondary.append(objBlock)
      }
    }

    if (u.isEmpty(list.primary) && checkType)
      list = this.getObjectivesList(Point2(1, 0), false)

    return list
  }

  function getObjectiveViewsArray(objectives) {
    return u.mapAdvanced(objectives, Callback(
      @(dataBlk, idx, arr)
        WwObjectiveView(
          dataBlk,
          this.getStatusBlock(dataBlk),
          this.side,
          arr.len() == 1 || idx == (arr.len() - 1)
        ),
      this))
  }

  function onEventWWLoadOperation(_params) {
    let objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    this.updateDynamicData(objectivesBlk)
    this.checkTimers()
  }

  function onEventWWOperationFinished(_params) {
    this.update()
    this.checkTimers()
  }

  function onTabChange() {
    this.updateReinforcementSpeedup()
  }

  function updateDynamicData(objectivesBlk) {
    this.dynamicBlk = u.copy(objectivesBlk?.status) || DataBlock()
    this.updateDynamicDataBlocks()
    this.updateReinforcementSpeedup()
  }

  function updateDynamicDataBlocks() {
    for (local i = 0; i < this.staticBlk.blockCount(); i++)
      this.updateDynamicDataBlock(this.staticBlk.getBlock(i))
  }

  function updateReinforcementSpeedup() {
    local reinforcementSpeedup = 0
    foreach (objectiveBlk in this.staticBlk)
      if (this.canShowObjective(objectiveBlk, true)) {
        let statusBlock = this.getStatusBlock(objectiveBlk)
        let oType = ::g_ww_objective_type.getTypeByTypeName(objectiveBlk?.type)
        let sideEnumVal = ww_side_val_to_name(this.side)

        reinforcementSpeedup += oType.getReinforcementSpeedupPercent(objectiveBlk, statusBlock, sideEnumVal)
      }

    wwEvent("ReinforcementSpeedupUpdated", { speedup = reinforcementSpeedup })
  }

  function updateDynamicDataBlock(objectiveBlk) {
    let objectiveBlockId = objectiveBlk.getBlockName()
    let statusBlock = this.getStatusBlock(objectiveBlk)

    let oType = ::g_ww_objective_type.getTypeByTypeName(objectiveBlk?.type)
    let sideEnumVal = ww_side_val_to_name(this.side)
    let result = oType.getUpdatableParamsArray(objectiveBlk, statusBlock, sideEnumVal)
    let zones = oType.getUpdatableZonesParams(objectiveBlk, statusBlock, sideEnumVal)

    let objectiveObj = this.scene.findObject(objectiveBlockId)
    if (!checkObj(objectiveObj))
      return

    let statusType = oType.getObjectiveStatus(statusBlock?.winner, sideEnumVal)
    objectiveObj.status = statusType.name

    let imageObj = objectiveObj.findObject("statusImg")
    if (checkObj(imageObj))
      imageObj["background-image"] = statusType.wwMissionObjImg

    let titleObj = objectiveObj.findObject(oType.getNameId(objectiveBlk, this.side))
    if (checkObj(titleObj))
      titleObj.setValue(oType.getName(objectiveBlk, statusBlock, sideEnumVal))

    foreach (block in result) {
      if (!("id" in block))
        continue

      let updatableParamObj = objectiveObj.findObject(block.id)
      if (!checkObj(updatableParamObj))
        continue

      foreach (textId in ["pName", "pValue"])
        if (textId in block) {
          let nameObj = updatableParamObj.findObject(textId)
          if (checkObj(nameObj))
            nameObj.setValue(block[textId])
        }

      if ("team" in block)
        updatableParamObj.team = block.team
    }

    if (zones.len())
      foreach (zone in zones) {
        let zoneObj = objectiveObj.findObject(zone.id)
        if (checkObj(zoneObj))
          zoneObj.team = zone.team
      }

    let descObj = objectiveObj.findObject("updatable_data_text")
    if (checkObj(descObj)) {
      let text = oType.getUpdatableParamsDescriptionText(objectiveBlk, statusBlock, sideEnumVal)
      descObj.setValue(text)
    }
  }

  function getStatusBlock(blk) {
    return this.dynamicBlk.getBlockByName(blk?.guiStatusBlk ?? blk.getBlockName())
  }

  function onOpenFullMissionObjects() {
    gui_handlers.WwObjectivesInfo.open()
  }

  function onHoverName(obj) {
    let zonesList = []
    for (local i = 0; i < obj.childrenCount(); i++) {
      let zoneObj = obj.getChild(i)
      if (!checkObj(zoneObj))
        continue

      zonesList.append(zoneObj.id)
    }
    if (zonesList.len())
      ww_mark_zones_as_outlined_by_name(zonesList)
  }

  function onHoverLostName(_obj) {
    wwClearOutlinedZones()
  }
}
