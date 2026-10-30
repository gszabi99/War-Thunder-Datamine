import "%globalScripts/sharedWatched.nut" as sharedWatched
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu, isOfflineMenu, disableNetwork
from "frp" import Computed
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE
from "%appGlobals/debugTools/dbgEnum.nut" import bitMaskToSstring

let loginState = sharedWatched("loginState", @() LOGIN_STATE.NOT_LOGGED_IN)
let isLoginRequired = sharedWatched("isLoginRequired", @() !shouldDisableMenu && !isOfflineMenu)

let readyToFullLoadMask = LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED



let hasFullLoginState = Computed(@() (loginState.get() & LOGIN_STATE.LOGGED_IN) == LOGIN_STATE.LOGGED_IN)

function hasLoginState(state) {
  return (loginState.get() & state) == state
}

function getStateDebugStr() {
  let state = loginState.get()
  return state == 0 ? "0" : bitMaskToSstring(LOGIN_STATE, state)
}

return freeze({
  loginState
  isProfileReceived = Computed(@() (loginState.get() & LOGIN_STATE.PROFILE_RECEIVED) != 0)
  isAuthorized = Computed(@() (loginState.get() & LOGIN_STATE.AUTHORIZED) != 0)
  hasFullLoginState
  isLoggedIn = Computed(@() !disableNetwork && hasFullLoginState.get())
  isReadyToFullLoad = Computed(@() (loginState.get() & readyToFullLoadMask) == readyToFullLoadMask)
  isLoginStarted = Computed(@() (loginState.get() & LOGIN_STATE.LOGIN_STARTED) != 0)
  isOnlineBinariesInited = Computed(@() (loginState.get() & LOGIN_STATE.ONLINE_BINARIES_INITED) != 0)
  isLoginRequired
  hasLoginState
  getStateDebugStr
})
