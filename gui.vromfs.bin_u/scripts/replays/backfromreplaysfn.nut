from "%scripts/dagui_library.nut" import mkHardPersist

let backState = mkHardPersist("replays.backFromReplaysFn")("backState", { isBackToReplays = false })
local _backFromReplaysFn = null

function setBackFromReplaysFn(fn, isBackToReplays = false) {
  _backFromReplaysFn = fn
  backState.isBackToReplays = isBackToReplays
}

return freeze({
  getBackFromReplaysFn = @() _backFromReplaysFn
  setBackFromReplaysFn
  isBackToReplays = @() backState.isBackToReplays
})