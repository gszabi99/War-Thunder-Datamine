from "%scripts/dagui_library.nut" import *
from "%scripts/login/loginConsts.nut" import LOGIN_STATE

let { bitMaskToSstring } = require("%scripts/debugTools/dbgEnum.nut")

let curLoginProcess = persist("curLoginProcess", @() { value = null})
let loginState = mkWatched(persist, "loginState", LOGIN_STATE.NOT_LOGGED_IN)

let readyToFullLoadMask = LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED

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
  isProfileReceived = Computed(@() (loginState.get() & LOGIN_STATE.PROFILE_RECEIVED) != 0)
  isAuthorized = Computed(@() (loginState.get() & LOGIN_STATE.AUTHORIZED) != 0)
  isLoggedIn = Computed(@() (loginState.get() & LOGIN_STATE.LOGGED_IN) == LOGIN_STATE.LOGGED_IN)
  hasLoginState
  isReadyToFullLoad = Computed(@() (loginState.get() & readyToFullLoadMask) == readyToFullLoadMask)
  loginState
  getStateDebugStr
  getCurLoginProcess = @() curLoginProcess.value
  setCurLoginProcess = @(newLoginProcess) curLoginProcess.value = newLoginProcess
  destroyLoginProgress
  isLoginStarted = Computed(@() (loginState.get() & LOGIN_STATE.LOGIN_STARTED) != 0)
}