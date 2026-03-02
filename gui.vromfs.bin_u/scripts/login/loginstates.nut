from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { bitMaskToSstring } = require("%scripts/debugTools/dbgEnum.nut")
let { loginState } = require("%appGlobals/login/loginState.nut")

local curLoginProcess = null

function hasLoginState(state) {
  return (loginState.get() & state) == state
}

function getStateDebugStr(state = null) {
  state = state ?? loginState.get()
  return state == 0 ? "0" : bitMaskToSstring(LOGIN_STATE, state)
}

function destroyLoginProgress() {
  if (curLoginProcess)
    curLoginProcess.destroy()
  curLoginProcess = null
}

return {
  hasLoginState
  getStateDebugStr
  getCurLoginProcess = @() curLoginProcess
  setCurLoginProcess = @(newLoginProcess) curLoginProcess = newLoginProcess
  destroyLoginProgress
}