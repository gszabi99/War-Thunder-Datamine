from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { wwGetArmyGroupsInfo } = require("worldwar")

local armyGroupsInfo = null

function getArmyGroupsInfo() {
  if (armyGroupsInfo != null)
    return armyGroupsInfo

  let blk = DataBlock()
  wwGetArmyGroupsInfo(blk)
  let items = blk.armyGroups % "item"
  armyGroupsInfo = items.reduce(function(res, v) {
    let key = v.owner.armyGroupIdx
    res[key] <- {}
    res[key].side <- v.owner.side
    return res
  }, {})

  return armyGroupsInfo
}

return {
  getArmyGroupsInfo
  clearArmyGroupsInfo = @() armyGroupsInfo = null
}