from "worldwar" import wwGetOperationState
from "worldwarConst" import OperationState

return freeze({
  isOperationPaused = @() wwGetOperationState() == OperationState.EOS_PAUSED
  isOperationFinished = @() wwGetOperationState() == OperationState.EOS_FINISHED
})