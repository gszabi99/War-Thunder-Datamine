let chard = require("chard")

const PROCESS_TIME_OUT = 60000

let function trainCrewUnitWithoutSwitchCurrUnit(crew, unit) {
  let unitName = unit.name
  let crewId = crew?.id ?? -1
  if ((crewId == -1) || (crew?.trainedSpec?[unitName] != null) || !unit.isUsable())
    return

  let trainedUnit = unit
  let onSuccessCb = @() ::broadcastEvent("CrewTakeUnit", { unit = trainedUnit })
  let onTrainCrew = function() {
    let taskId = chard.trainCrewAircraft(crewId, unitName, true)
    let taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = PROCESS_TIME_OUT
    }
    ::g_tasker.addTask(taskId, taskOptions, onSuccessCb)
  }

  let cost = ::g_crew.getCrewTrainCost(crew, unit)
  if (cost.isZero())
  {
    onTrainCrew()
    return
  }

  let msgText = ::warningIfGold(::format(::loc("shop/needMoneyQuestion_retraining"),
    cost.getTextAccordingToBalance()), cost)
  ::scene_msg_box("train_crew_unit", null, msgText,
    [ ["ok", function() {
        if (::check_balance_msgBox(cost))
          onTrainCrew()
      }],
      ["cancel", @() null ]
   ], "ok")
}


let function createBatchTrainCrewRequestBlk(requestData) {
  let requestBlk = ::DataBlock()
  requestBlk.batchTrainCrew <- ::DataBlock()
  foreach (requestItem in requestData) {
    let itemBlk = ::DataBlock()
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
let function batchTrainCrew(requestData, taskOptions = null, onSuccess = null, onError = null, handler = null) {
  let onTaskSuccess = onSuccess ? ::Callback(onSuccess, handler) : null
  let onTaskError   = onError   ? ::Callback(onError,   handler) : null

  if (!requestData.len()) {
    if (onTaskSuccess)
      onTaskSuccess()
    return
  }

  let requestBlk = createBatchTrainCrewRequestBlk(requestData)
  let taskId = ::char_send_blk("cln_bulk_train_aircraft", requestBlk)
  ::g_tasker.addTask(taskId, taskOptions, onTaskSuccess, onTaskError)
}

return {
  trainCrewUnitWithoutSwitchCurrUnit = trainCrewUnitWithoutSwitchCurrUnit
  batchTrainCrew = batchTrainCrew
  createBatchTrainCrewRequestBlk = createBatchTrainCrewRequestBlk
}
