from "%rGui/globals/ui_library.nut" import *

let { Point2 } = require("dagor.math")
let DataBlock = require("DataBlock")

let { RwrBlkName, BlkFileName } = require("planeState/planeToolsState.nut")

let rangeDefault = Point2(5000, 50000)

let rwrSetting = Computed(function() {
  local res = {
    direction = [],
    directionMap = [],
    presence = [],
    presenceMap = [],
    presenceDefault = [],
    targetTracking = false,
    range = rangeDefault
  }

  local rwrBlkName = null
  local rwrBlk = null

  if (RwrBlkName.value == "") {
    let blk = DataBlock()
    let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
    if (!blk.tryLoad(fileName))
      return res

    let sensorsBlk = blk.getBlockByName("sensors")
    if (sensorsBlk == null)
      return res

    for (local i = 0; i < sensorsBlk.blockCount(); i++) {
      let sensorBlk = sensorsBlk.getBlock(i)
      let sensorBlkName = sensorBlk.getStr("blk", "")
      let sensorDataBlk = DataBlock()
      if (sensorDataBlk.tryLoad(sensorBlkName)) {
        let sensorType = sensorDataBlk.getStr("type", "")
        if (sensorType == "rwr") {
          rwrBlk = sensorDataBlk
          rwrBlkName = sensorBlkName
          break
        }
      }
    }

    if (rwrBlk == null)
      return res
  }
  else {
    rwrBlkName = RwrBlkName.value
    rwrBlk = DataBlock()
    if (!rwrBlk.tryLoad(RwrBlkName.value))
      return res
    else {
      let sensorType = rwrBlk.getStr("type", "")
      if (sensorType != "rwr")
        return res
    }
  }

  res.targetTracking = rwrBlk.getBool("targetTracking", false)

  res.range = rwrBlk.getPoint2("targetRange", rangeDefault)

  let groupsBlk = rwrBlk.getBlockByName("groups")
  if (groupsBlk == null)
    return res

  local groupNames = []
  for (local i = 0; i < groupsBlk.blockCount(); i++) {
    let groupBlk = groupsBlk.getBlock(i)
    let groupName = groupBlk.getStr("name", "")
    let blocked = groupBlk.getBool("block", false)
    if (blocked == true)
      continue
    local groupIndex = groupNames.findindex(@(name) name == groupName)
    if (groupIndex == null) {
      groupIndex = groupNames.len()
      groupNames.append(groupName)
    }
  }

  let targetsDirectionGroupsBlk = rwrBlk.getBlockByName("targetsDirectionGroups")
  if (targetsDirectionGroupsBlk != null) {
    for (local i = 0; i < targetsDirectionGroupsBlk.blockCount(); i++) {
      let targetsDirectionGroupBlk = targetsDirectionGroupsBlk.getBlock(i)
      let targetsDirectionGroupText = loc(targetsDirectionGroupBlk.getStr("text", "?"))
      local directionIndex = res.direction.findindex(@(dir) dir.text == targetsDirectionGroupText)
      if (directionIndex == null) {
        directionIndex = res.direction.len()
        res.direction.append( { text = targetsDirectionGroupText } )
      }
      for (local j = 0; j < targetsDirectionGroupBlk.paramCount(); j++) {
        if (targetsDirectionGroupBlk.getParamName(j) != "group")
          continue
        let directionGroupName = targetsDirectionGroupBlk.getParamValue(j)
        local groupIndex = groupNames.findindex(@(groupName) groupName == directionGroupName)
        assert(groupIndex != null, $"RWR target direction group \"{directionGroupName}\" not found for targetsDirectionGroup {directionIndex} in {rwrBlkName}")
        if (groupIndex != null) {
          res.directionMap.resize(max(res.directionMap.len(), groupIndex + 1))
          res.directionMap[groupIndex] = directionIndex
        }
      }
    }
  }

  let noTargetsDirectionGroup = rwrBlk.getBlockByName("noTargetsDirectionGroup")
  if (noTargetsDirectionGroup != null) {
    for (local j = 0; j < noTargetsDirectionGroup.paramCount(); j++) {
      if (noTargetsDirectionGroup.getParamName(j) != "group")
        continue
      let noDirectionGroupName = noTargetsDirectionGroup.getParamValue(j)
      local groupIndex = groupNames.findindex(@(groupName) groupName == noDirectionGroupName)
      assert(groupIndex != null, $"RWR target direction group \"{noDirectionGroupName}\" not found for noTargetsDirectionGroup in {rwrBlkName}")
      if (groupIndex != null) {
        res.directionMap.resize(max(res.directionMap.len(), groupIndex + 1))
        res.directionMap[groupIndex] = -1
      }
    }
  }

  let targetsPresenceGroupsBlk = rwrBlk.getBlockByName("targetsPresenceGroups")
  if (targetsPresenceGroupsBlk != null) {
    for (local i = 0; i < targetsPresenceGroupsBlk.blockCount(); i++) {
      let targetsPresenceGroupBlk = targetsPresenceGroupsBlk.getBlock(i)
      let targetsPresenceGroupText = loc(targetsPresenceGroupBlk.getStr("text", "?"))
      local presenceIndex = res.presence.findindex(@(pres) pres.text == targetsPresenceGroupText)
      if (presenceIndex == null) {
        presenceIndex = res.presence.len()
        res.presence.append( {
          text = targetsPresenceGroupText,
          search = targetsPresenceGroupBlk.getBool("search", true),
          track = targetsPresenceGroupBlk.getBool("track", true),
          launch = targetsPresenceGroupBlk.getBool("launch", true)
        } )
      }
      for (local j = 0; j < targetsPresenceGroupBlk.paramCount(); j++) {
        if (targetsPresenceGroupBlk.getParamName(j) != "group")
          continue
        let presenceGroupName = targetsPresenceGroupBlk.getParamValue(j)
        local groupIndex = groupNames.findindex(@(groupName) groupName == presenceGroupName)
        assert(groupIndex != null, $"RWR target presence group \"{presenceGroupName}\" not found for targetsPresenceGroup {i} in {rwrBlkName}")
        if (groupIndex != null) {
          res.presenceMap.resize(max(res.presenceMap.len(), groupIndex + 1))
          if (res.presenceMap[groupIndex] == null)
            res.presenceMap[groupIndex] = []
          res.presenceMap[groupIndex].append(presenceIndex)
        }
      }
      if (targetsPresenceGroupBlk.getBool("default", false))
        res.presenceDefault.append(presenceIndex)
    }
  }

  return res
})

return rwrSetting