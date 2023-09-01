from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")

let { BlkFileName } = require("planeState/planeToolsState.nut")

let rwrSetting = Computed(function() {
  local res = {
    direction = [],
    directionMap = [],
    presence = [],
    presenceMap = []
  }
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res

  let sensorsBlk = blk.getBlockByName("sensors")
  if (sensorsBlk == null)
    return res

  local rwrBlk = null
  for (local i = 0; i < sensorsBlk.blockCount(); i++) {
    let sensorBlk = sensorsBlk.getBlock(i)
    let sensorBlkName = sensorBlk.getStr("blk", "")
    let sensorDataBlk = DataBlock()
    if (sensorDataBlk.tryLoad(sensorBlkName)) {
      let sensorType = sensorDataBlk.getStr("type", "")
      if (sensorType == "rwr") {
        rwrBlk = sensorDataBlk
        break
      }
    }
  }

  if (rwrBlk == null)
    return res

  let groupsBlk = rwrBlk.getBlockByName("groups")
  if (groupsBlk == null)
    return res

  local groupNames = []
  for (local i = 0; i < groupsBlk.blockCount(); i++) {
    let groupBlk = groupsBlk.getBlock(i)
    let groupName = groupBlk.getStr("name", "")
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
        assert(groupIndex != null, $"RWR target direction group \"{directionGroupName}\" not found for targetsDirectionGroup {directionIndex}")
        if (groupIndex != null) {
          res.directionMap.resize(max(res.directionMap.len(), groupIndex + 1))
          res.directionMap[groupIndex] = directionIndex
        }
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
        assert(groupIndex != null, $"RWR target presence group \"{presenceGroupName}\" not found for targetsPresenceGroup {i}")
        if (groupIndex != null) {
          res.presenceMap.resize(max(res.presenceMap.len(), groupIndex + 1))
          if (res.presenceMap[groupIndex] == null)
            res.presenceMap[groupIndex] = []
          res.presenceMap[groupIndex].append(presenceIndex)
        }
      }
    }
  }

  return res
})

return rwrSetting