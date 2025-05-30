from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { addTask } = require("%scripts/tasker.nut")

function createBatchTrainCrewRequestBlk(requestData) {
  let requestBlk = DataBlock()
  requestBlk.batchTrainCrew <- DataBlock()
  foreach (requestItem in requestData) {
    let itemBlk = DataBlock()
    itemBlk.crewId <- requestItem.crewId
    itemBlk.unitName <- requestItem.airName
    requestBlk.batchTrainCrew.trainCrew <- itemBlk
  }
  return requestBlk
}





function batchTrainCrew(requestData, taskOptions = null, onSuccess = null, onError = null, handler = null) {
  let onTaskSuccess = onSuccess ? Callback(onSuccess, handler) : null
  let onTaskError   = onError   ? Callback(onError,   handler) : null

  if (!requestData.len()) {
    if (onTaskSuccess)
      onTaskSuccess()
    return
  }

  let requestBlk = createBatchTrainCrewRequestBlk(requestData)
  let taskId = char_send_blk("cln_bulk_train_aircraft", requestBlk)
  addTask(taskId, taskOptions, onTaskSuccess, onTaskError)
}

return {
  batchTrainCrew
  createBatchTrainCrewRequestBlk
}
