from "%scripts/dagui_natives.nut" import char_send_blk, shop_upgrade_crew
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { addTask } = require("%scripts/tasker.nut")
let { buySkillPointsPack } = require("%scripts/crew/crewPointsBuyActions.nut")
let { getPacksToBuyAmount } = require("%scripts/crew/crewPoints.nut")
let { doWithAllSkills, getCrewMaxSkillValue, getCrewSkillValue,
getCrewSkillPointsToMaxAllSkills, getCrewCountry
} = require("%scripts/crew/crew.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { flushSlotbarUpdate, suspendSlotbarUpdates } = require("%scripts/slotbar/slotbarState.nut")


function unlockCrew(crewId, byGold, cost) {
  let blk = DataBlock()
  blk["crew"] = crewId
  blk["gold"] = byGold
  blk["cost"] = cost?.wp ?? 0
  blk["costGold"] = cost?.gold ?? 0

  return char_send_blk("cln_unlock_crew", blk)
}

function maximazeAllSkillsImpl(crew, unit, crewUnitType) {
  let blk = DataBlock()
  doWithAllSkills(crew, crewUnitType,
    function(page, skillItem) {
      let maxValue = getCrewMaxSkillValue(skillItem)
      let curValue = getCrewSkillValue(crew.id, unit, page.id, skillItem.name)
      if (maxValue > curValue)
        blk.addBlock(page.id)[skillItem.name] = maxValue - curValue
    }
  )

  let isTaskCreated = addTask(
    shop_upgrade_crew(crew.id, blk),
    { showProgressBox = true },
    function() {
      broadcastEvent("CrewSkillsChanged", { crew, unit })
      flushSlotbarUpdate()
    },
    @(_err) flushSlotbarUpdate()
  )

  if (isTaskCreated)
    suspendSlotbarUpdates()
}

function buyAllCrewSkills(crew, unit, crewUnitType) {
  let totalPointsToMax = getCrewSkillPointsToMaxAllSkills(crew, unit, crewUnitType)
  if (totalPointsToMax <= 0)
    return

  let curPoints = getTblValue("skillPoints", crew, 0)
  if (curPoints >= totalPointsToMax)
    return maximazeAllSkillsImpl(crew, unit, crewUnitType)

  let packs = getPacksToBuyAmount(getCrewCountry(crew), totalPointsToMax)
  if (!packs.len())
    return

  buySkillPointsPack(crew, packs, @() maximazeAllSkillsImpl(crew, unit, crewUnitType))
}

return {
  unlockCrew
  buyAllCrewSkills
}
