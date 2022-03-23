let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")


::gui_handlers.wwObjective <- class extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/worldWarObjectivesInfo"
  sceneBlkName = null
  objectiveItemTpl = "%gui/worldWar/worldWarObjectiveItem"
  singleOperationTplName = "%gui/worldWar/operationString"

  staticBlk = null
  dynamicBlk = null

  timersArray = null

  side = ::SIDE_NONE
  needShowOperationDesc = true
  reqFullMissionObjectsButton = true
  restrictShownObjectives = false
  hasObjectiveDesc = false

  function getSceneTplView()
  {
    return {
      reqFullMissionObjectsButton = reqFullMissionObjectsButton
    }
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function isValid()
  {
    return ::checkObj(scene) && ::checkObj(scene.findObject("ww_mission_objectives"))
  }

  function initScreen()
  {
    update()
    checkTimers()
  }

  function update()
  {
    let placeObj = scene.findObject("ww_mission_objectives")
    if (!::check_obj(placeObj))
      return

    updateObjectivesData()

    let curOperation = getOperationById(::ww_get_operation_id())
    let unseenIcon = curOperation
      ? bhvUnseen.makeConfigStr(SEEN.WW_MAPS_OBJECTIVE, curOperation.getMapId()) : null
    let objectivesList = getObjectivesList(getObjectivesCount(false))
    let view = {
      unseenIcon = unseenIcon
      objectiveBlock = getObjectiveBlocksArray()
      reqFullMissionObjectsButton = reqFullMissionObjectsButton
      hiddenObjectives = ::max(objectivesList.primaryCount - getShowMaxObjectivesCount().x, 0)
      hasObjectiveDesc = hasObjectiveDesc
    }
    let data = ::handyman.renderCached(objectiveItemTpl, view)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function checkTimers()
  {
    timersArray = []
    foreach (id, dataBlk in staticBlk)
    {
      let statusBlk = getStatusBlock(dataBlk)
      let oType = ::g_ww_objective_type.getTypeByTypeName(dataBlk?.type)
      let handler = this
      foreach (param, func in oType.timersArrayByParamName)
        timersArray.extend(func(handler, scene, param, dataBlk, statusBlk, oType, side))
    }
  }

  function updateObjectivesData()
  {
    let objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    staticBlk = ::u.copy(objectivesBlk?.data) || ::DataBlock()
    dynamicBlk = ::u.copy(objectivesBlk?.status) || ::DataBlock()
  }

  function canShowObjective(objBlock, checkType = true, isForceVisible = false)
  {
    if (::g_world_war.isDebugModeEnabled())
      return true

    if (needShowOperationDesc && !isForceVisible && !objBlock?.showInOperationDesc)
      return false

    if (checkType)
    {
      let oType = ::g_ww_objective_type.getTypeByTypeName(objBlock?.type)
      let isDefender = oType.isDefender(objBlock, ::ww_side_val_to_name(side))

      if (objBlock?.showOnlyForDefenders)
        return isDefender

      if (objBlock?.showOnlyForAttackers)
        return !isDefender

      if (objBlock?.type == ::g_ww_objective_type.OT_DONT_AFK.typeName)
        return false
    }

    return true
  }

  function getShowMaxObjectivesCount()
  {
    let winner = ::ww_get_operation_winner()
    if (restrictShownObjectives && winner != ::SIDE_NONE)
      return ::Point2(1, 0)

    let objectivesCount = getObjectivesCount()

    if (!restrictShownObjectives || ::g_world_war.isDebugModeEnabled())
      return objectivesCount

    let guiScene = scene.getScene()

    let panelObj = guiScene["content_block_1"]
    let holderObj = panelObj.getParent()

    let busyHeight = holderObj.findObject("operation_info").getSize()[1]

    let content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)
    let blockHeight = content1BlockHeight - busyHeight

    local headers = 0
    if (objectivesCount.x > 0) headers++
    if (objectivesCount.y > 0) headers++
    let reservedHeight = guiScene.calcString("1@frameHeaderHeight + " + headers + "@objectiveBlockHeaderHeight", null)

    let availObjectivesHeight = blockHeight - reservedHeight

    let singleObjectiveHeight = guiScene.calcString("1@objectiveHeight", null)
    let allowObjectives = availObjectivesHeight / singleObjectiveHeight
    let res = ::Point2(0, 0)
    res.x = ::max(1, ::min(objectivesCount.x, allowObjectives))
    if (allowObjectives > res.x)
      res.y = ::max(1, ::min(objectivesCount.y, allowObjectives))
    return res
  }

  function getObjectivesCount(checkType = true)
  {
    let objectivesCount = ::Point2(0,0)
    foreach (block in staticBlk)
      if (canShowObjective(block, checkType))
      {
        if (block?.mainObjective)
          objectivesCount.x++
        else
          objectivesCount.y++
      }

    return objectivesCount
  }

  function onEventWWAFKTimerStop(params)
  {
    setTopPosition(getShowMaxObjectivesCount())
  }

  function onEventWWAFKTimerStart(params)
  {
    setTopPosition(getShowMaxObjectivesCount(), params?.needResize ? 1 : 0)
  }

  function setTopPosition(objectivesCount, addRow = 0)
  {
    if (!restrictShownObjectives)
      return

    let guiScene = scene.getScene()
    let content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)

    let busyHeight = guiScene["operation_info"].getSize()[1]

    local headers = 0
    if (objectivesCount.x > 0) headers++
    if (objectivesCount.y > 0) headers++

    let reservedHeight = guiScene.calcString("1@frameHeaderHeight + "
      + headers + "@objectiveBlockHeaderHeight", null)
    let objectivesHeight = guiScene.calcString(
      (objectivesCount.x + objectivesCount.y + addRow) + "@objectiveHeight", null)

    let panelObj = guiScene["content_block_1"]
    panelObj.top = content1BlockHeight - busyHeight - reservedHeight - objectivesHeight
  }

  function getObjectiveBlocksArray()
  {
    let availableObjectiveSlots = getShowMaxObjectivesCount()
    setTopPosition(availableObjectiveSlots)

    let objectivesList = getObjectivesList(availableObjectiveSlots)

    local countryIcon = ""
    let groups = ::g_world_war.getArmyGroupsBySide(side)
    if (groups.len() > 0)
      countryIcon = groups[0].getCountryIcon()

    let objectiveBlocks = []
    foreach (name in ["primary", "secondary"])
    {
      let arr = objectivesList[name]
      objectiveBlocks.append({
          id = name,
          isPrimary = name == "primary"
          countryIcon = countryIcon
          hide = arr.len() == 0
          objectives = getObjectiveViewsArray(arr)
        })
    }

    return objectiveBlocks
  }

  function getAFKStatusBlock()
  {
    if (!::g_world_war.isCurrentOperationFinished())
      return null
    foreach (idx, inst in staticBlk)
      if(::g_string.startsWith(idx, "dont_afk") && getStatusBlock(inst)?.winner)
        return inst
    return null
  }

  function getObjectivesList(availableObjectiveSlots, checkType = true)
  {
    local list = {
      primary = []
      secondary = []
      primaryCount = 0
    }

    let statusBlk = getAFKStatusBlock()
    list.primary = statusBlk ? [statusBlk] : []
    list.primaryCount = list.primary.len()
    if(list.primaryCount)
      return list

    let usedObjectiveSlots = ::Point2(0,0)
    for (local i = 0; i < staticBlk.blockCount(); i++)
    {
      let objBlock = staticBlk.getBlock(i)
      if (!canShowObjective(objBlock, checkType, true))
        continue

      list.primaryCount += objBlock?.mainObjective ? 1 : 0

      if (usedObjectiveSlots.x >= availableObjectiveSlots.x
        && usedObjectiveSlots.y >= availableObjectiveSlots.y)
        continue

      if (!canShowObjective(objBlock, checkType))
        continue

      objBlock.id <- objBlock.getBlockName()

      if (objBlock?.mainObjective && usedObjectiveSlots.x < availableObjectiveSlots.x)
      {
        usedObjectiveSlots.x++
        list.primary.append(objBlock)
      }
      else if (usedObjectiveSlots.y < availableObjectiveSlots.y)
      {
        usedObjectiveSlots.y++
        list.secondary.append(objBlock)
      }
    }

    if (::u.isEmpty(list.primary) && checkType)
      list = getObjectivesList(::Point2(1,0), false)

    return list
  }

  function getObjectiveViewsArray(objectives)
  {
    return ::u.mapAdvanced(objectives, ::Callback(
      @(dataBlk, idx, arr)
        ::WwObjectiveView(
          dataBlk,
          getStatusBlock(dataBlk),
          side,
          arr.len() == 1 || idx == (arr.len() - 1)
        ),
      this))
  }

  function onEventWWLoadOperation(params)
  {
    let objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    updateDynamicData(objectivesBlk)
    checkTimers()
  }

  function onEventWWOperationFinished(params)
  {
    update()
    checkTimers()
  }

  function onTabChange()
  {
    updateReinforcementSpeedup()
  }

  function updateDynamicData(objectivesBlk)
  {
    dynamicBlk = ::u.copy(objectivesBlk?.status) || ::DataBlock()
    updateDynamicDataBlocks()
    updateReinforcementSpeedup()
  }

  function updateDynamicDataBlocks()
  {
    for (local i = 0; i < staticBlk.blockCount(); i++)
      updateDynamicDataBlock(staticBlk.getBlock(i))
  }

  function updateReinforcementSpeedup()
  {
    local reinforcementSpeedup = 0
    foreach (objectiveBlk in staticBlk)
      if (canShowObjective(objectiveBlk, true))
      {
        let statusBlock = getStatusBlock(objectiveBlk)
        let oType = ::g_ww_objective_type.getTypeByTypeName(objectiveBlk?.type)
        let sideEnumVal = ::ww_side_val_to_name(side)

        reinforcementSpeedup += oType.getReinforcementSpeedupPercent(objectiveBlk, statusBlock, sideEnumVal)
      }

    ::ww_event("ReinforcementSpeedupUpdated", { speedup = reinforcementSpeedup })
  }

  function updateDynamicDataBlock(objectiveBlk)
  {
    let objectiveBlockId = objectiveBlk.getBlockName()
    let statusBlock = getStatusBlock(objectiveBlk)

    let oType = ::g_ww_objective_type.getTypeByTypeName(objectiveBlk?.type)
    let sideEnumVal = ::ww_side_val_to_name(side)
    let result = oType.getUpdatableParamsArray(objectiveBlk, statusBlock, sideEnumVal)
    let zones = oType.getUpdatableZonesParams(objectiveBlk, statusBlock, sideEnumVal)

    let objectiveObj = scene.findObject(objectiveBlockId)
    if (!::checkObj(objectiveObj))
      return

    let statusType = oType.getObjectiveStatus(statusBlock?.winner, sideEnumVal)
    objectiveObj.status = statusType.name

    let imageObj = objectiveObj.findObject("statusImg")
    if (::checkObj(imageObj))
      imageObj["background-image"] = statusType.wwMissionObjImg

    let titleObj = objectiveObj.findObject(oType.getNameId(objectiveBlk, side))
    if (::checkObj(titleObj))
      titleObj.setValue(oType.getName(objectiveBlk, statusBlock, sideEnumVal))

    foreach (block in result)
    {
      if (!("id" in block))
        continue

      let updatableParamObj = objectiveObj.findObject(block.id)
      if (!::checkObj(updatableParamObj))
        continue

      foreach (textId in ["pName", "pValue"])
        if (textId in block)
        {
          let nameObj = updatableParamObj.findObject(textId)
          if (::checkObj(nameObj))
            nameObj.setValue(block[textId])
        }

      if ("team" in block)
        updatableParamObj.team = block.team
    }

    if (zones.len())
      foreach(zone in zones)
      {
        let zoneObj = objectiveObj.findObject(zone.id)
        if (::checkObj(zoneObj))
          zoneObj.team = zone.team
      }

    let descObj = objectiveObj.findObject("updatable_data_text")
    if (::check_obj(descObj))
    {
      let text = oType.getUpdatableParamsDescriptionText(objectiveBlk, statusBlock, sideEnumVal)
      descObj.setValue(text)
    }
  }

  function getStatusBlock(blk)
  {
    return dynamicBlk.getBlockByName(blk?.guiStatusBlk ?? blk.getBlockName())
  }

  function onOpenFullMissionObjects()
  {
    ::gui_handlers.WwObjectivesInfo.open()
  }

  function onHoverName(obj)
  {
    let zonesList = []
    for (local i = 0; i < obj.childrenCount(); i++)
    {
      let zoneObj = obj.getChild(i)
      if (!::checkObj(zoneObj))
        continue

      zonesList.append(zoneObj.id)
    }
    if (zonesList.len())
      ::ww_mark_zones_as_outlined_by_name(zonesList)
  }

  function onHoverLostName(obj)
  {
    ::ww_clear_outlined_zones()
  }
}
