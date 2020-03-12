local chard = require_native("chard")

const PROCESS_TIME_OUT = 60000

local function trainCrewUnitWithoutSwitchCurrUnit(crew, unit) {
  local unitName = unit.name
  local crewId = crew?.id ?? -1
  if ((crewId == -1) || (crew?.trainedSpec?[unitName] != null) || !unit.isUsable())
    return

  local trainedUnit = unit
  local onSuccessCb = @() ::broadcastEvent("CrewTakeUnit", { unit = trainedUnit })
  local onTrainCrew = function() {
    local taskId = chard.trainCrewAircraft(crewId, unitName, true)
    local taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = PROCESS_TIME_OUT
    }
    ::g_tasker.addTask(taskId, taskOptions, onSuccessCb)
  }

  local cost = ::g_crew.getCrewTrainCost(crew, unit)
  if (cost.isZero())
  {
    onTrainCrew()
    return
  }

  local msgText = ::warningIfGold(::format(::loc("shop/needMoneyQuestion_retraining"),
    cost.getTextAccordingToBalance()), cost)
  ::scene_msg_box("train_crew_unit", null, msgText,
    [ ["ok", function() {
        if (::check_balance_msgBox(cost))
          onTrainCrew()
      }],
      ["cancel", @() null ]
   ], "ok")
}

return {
  trainCrewUnitWithoutSwitchCurrUnit = trainCrewUnitWithoutSwitchCurrUnit
}
