local chard = ::require_native("chard")

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


local function createBatchTrainCrewRequestBlk(requestData) {
  local requestBlk = ::DataBlock()
  requestBlk.batchTrainCrew <- ::DataBlock()
  foreach (requestItem in requestData) {
    local itemBlk = ::DataBlock()
    itemBlk.crewId <- requestItem.crewId
    itemBlk.unitName <- requestItem.airName
    requestBlk.batchTrainCrew.trainCrew <- itemBlk
  }
  return requestBlk
}

/**
 * @param onSuccess - Callback func, has no params.
 * @param onError   - Callback func, MUST take 1 param: integer taskResult.
 */
local function batchTrainCrew(requestData, taskOptions = null, onSuccess = null, onError = null, handler = null) {
  local onTaskSuccess = onSuccess ? ::Callback(onSuccess, handler) : null
  local onTaskError   = onError   ? ::Callback(onError,   handler) : null

  if (!requestData.len()) {
    if (onTaskSuccess)
      onTaskSuccess()
    return
  }

  local requestBlk = createBatchTrainCrewRequestBlk(requestData)
  local taskId = ::char_send_blk("cln_bulk_train_aircraft", requestBlk)
  ::g_tasker.addTask(taskId, taskOptions, onTaskSuccess, onTaskError)
}

return {
  trainCrewUnitWithoutSwitchCurrUnit = trainCrewUnitWithoutSwitchCurrUnit
  batchTrainCrew = batchTrainCrew
  createBatchTrainCrewRequestBlk = createBatchTrainCrewRequestBlk
}
