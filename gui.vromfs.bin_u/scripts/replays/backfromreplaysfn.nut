local _backFromReplaysFn = null

function setBackFromReplaysFn(fn) {
  _backFromReplaysFn = fn
}

return {
  getBackFromReplaysFn = @() _backFromReplaysFn
  setBackFromReplaysFn
}