let { wwGetOperationState } = require("worldwar")
let { OperationState } = require("worldwarConst")

return {
  isOperationPaused = @() wwGetOperationState() == OperationState.EOS_PAUSED
  isOperationFinished = @() wwGetOperationState() == OperationState.EOS_FINISHED
}