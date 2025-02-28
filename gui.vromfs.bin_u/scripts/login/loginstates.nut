from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { bitMaskToSstring } = require("%scripts/debugTools/dbgEnum.nut")
let { loginState } = require("%appGlobals/login/loginState.nut")

let curLoginProcess = persist("curLoginProcess", @() { value = null})

function hasLoginState(state) {
  return (loginState.get() & state) == state
}

function getStateDebugStr(state = null) {
  state = state ?? loginState.get()
  return state == 0 ? "0" : bitMaskToSstring(LOGIN_STATE, state)
}

function destroyLoginProgress() {
  if (curLoginProcess.value)
    curLoginProcess.value.destroy()
  curLoginProcess.value = null
}

return {
  hasLoginState
  getStateDebugStr
  getCurLoginProcess = @() curLoginProcess.value
  setCurLoginProcess = @(newLoginProcess) curLoginProcess.value = newLoginProcess
  destroyLoginProgress
}