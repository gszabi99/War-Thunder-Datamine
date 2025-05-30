from "%scripts/dagui_natives.nut" import shop_specialize_crew
from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let chard = require("chard")
let { addTask } = require("%scripts/tasker.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getCrewTrainCost, getCrewLevel } = require("%scripts/crew/crew.nut")
let { crewSpecTypes, getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { canSpendGoldOnUnitWithPopup } = require("%scripts/unit/unitActions.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")

const PROCESS_TIME_OUT = 60000

function trainCrewUnitWithoutSwitchCurrUnit(crew, unit) {
  let unitName = unit.name
  let crewId = crew?.id ?? -1
  if ((crewId == -1) || (crew?.trainedSpec?[unitName] != null) || !unit.isUsable())
    return

  let trainedUnit = unit
  let onSuccessCb = @() broadcastEvent("CrewTakeUnit", { unit = trainedUnit })
  let onTrainCrew = function() {
    let taskId = chard.trainCrewAircraft(crewId, unitName, true)
    let taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = PROCESS_TIME_OUT
    }
    addTask(taskId, taskOptions, onSuccessCb)
  }

  let cost = getCrewTrainCost(crew, unit)
  if (cost.isZero()) {
    onTrainCrew()
    return
  }

  let msgText = warningIfGold(format(loc("shop/needMoneyQuestion_retraining"),
    cost.getTextAccordingToBalance()), cost)
  scene_msg_box("train_crew_unit", null, msgText,
    [ ["ok", function() {
        if (checkBalanceMsgBox(cost))
          onTrainCrew()
      }],
      ["cancel", @() null ]
   ], "ok")
}


function upgradeUnitSpecImpl(crew, unit, upgradesAmount = 1) {
  let taskId = shop_specialize_crew(crew.id, unit.name)
  let progBox = { showProgressBox = true }
  upgradesAmount--
  let self = callee()
  let onTaskSuccess =  function() {
    ::updateAirAfterSwitchMod(unit)
    updateGamercards()
    broadcastEvent("QualificationIncreased", { unit = unit, crew = crew })

    if (upgradesAmount > 0)
      return self(crew, unit, upgradesAmount)
    if (getTblValue("aircraft", crew) != unit.name)
      showInfoMsgBox(format(loc("msgbox/qualificationIncreased"), getUnitName(unit)))
  }

  addTask(taskId, progBox, onTaskSuccess)
}

function upgradeUnitSpec(crew, unit, crewUnitTypeToCheck = null, nextSpecType = null) {
  if (!unit)
    return showInfoMsgBox(loc("shop/aircraftNotSelected"))

  if ((crew?.id ?? -1) == -1)
    return showInfoMsgBox(loc("mainmenu/needRecruitCrewWarning"))

  if (!unit.isUsable())
    return showInfoMsgBox(loc("weaponry/unit_not_bought"))

  let curSpecType = getSpecTypeByCrewAndUnit(crew, unit)
  if (curSpecType == crewSpecTypes.UNKNOWN) {
    trainCrewUnitWithoutSwitchCurrUnit(crew, unit)
    return
  }

  if (!curSpecType.hasNextType())
    return

  if (!nextSpecType)
    nextSpecType = curSpecType.getNextType()
  local upgradesAmount = nextSpecType.code - curSpecType.code
  if (upgradesAmount <= 0)
    return

  let unitTypeSkillsMsg = $"<b>{colorize("warningTextColor", loc("crew/qualifyOnlyForSameType"))}</b>"

  let crewUnitType = unit.getCrewUnitType()
  let reqLevel = nextSpecType.getReqCrewLevel(unit)
  let crewLevel = getCrewLevel(crew, unit, crewUnitType)

  local msgLocId = "shop/needMoneyQuestion_increaseQualify"
  let msgLocParams = {
    unitName = colorize("userlogColoredText", getUnitName(unit))
    wantedQualify = colorize("userlogColoredText", nextSpecType.getName())
    reqLevel = colorize("badTextColor", reqLevel)
  }

  if (reqLevel > crewLevel) {
    nextSpecType = curSpecType.getNextMaxAvailableType(unit, crewLevel)
    upgradesAmount = nextSpecType.code - curSpecType.code
    if (upgradesAmount <= 0) {
      local msgText = loc("crew/msg/qualifyRequirement", msgLocParams)
      if (crewUnitTypeToCheck != null && crewUnitType != crewUnitTypeToCheck)
        msgText = "".concat("\n", unitTypeSkillsMsg)
      showInfoMsgBox(msgText)
      return
    }
    else {
      msgLocId = "shop/ask/increaseLowerQualify"
      msgLocParams.targetQualify <- colorize("userlogColoredText", nextSpecType.getName())
    }
  }

  let cost = curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit, nextSpecType.code)
  if (cost.gold > 0 && !canSpendGoldOnUnitWithPopup(unit))
    return

  msgLocParams.cost <- colorize("activeTextColor", cost.getTextAccordingToBalance())

  if (cost.isZero())
    return upgradeUnitSpecImpl(crew, unit, upgradesAmount)

  let msgText = warningIfGold(
    "".concat(loc(msgLocId, msgLocParams), "\n\n",
      loc("shop/crewQualifyBonuses", {
        qualification = colorize("userlogColoredText", nextSpecType.getName())
        bonuses = nextSpecType.getFullBonusesText(crewUnitType, curSpecType.code) }),
      "\n", unitTypeSkillsMsg),
    cost)
  scene_msg_box("purchase_ask", null, msgText,
    [
      ["yes", function() {
                 if (checkBalanceMsgBox(cost))
                   upgradeUnitSpecImpl(crew, unit, upgradesAmount)
               }
      ],
      ["no", function() {}]
    ],
    "yes",
    {
      cancel_fn = function() {}
      font = "fontNormal"
    }
  )
}

return {
  trainCrewUnitWithoutSwitchCurrUnit
  upgradeUnitSpec
}
