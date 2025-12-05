from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { Computed } = require("frp")
let sharedWatched = require("%globalScripts/sharedWatched.nut")
let { shouldDisableMenu, isOfflineMenu } = require("%globalScripts/clientState/initialState.nut")

let loginState = sharedWatched("loginState", @() LOGIN_STATE.NOT_LOGGED_IN)
let isLoginRequired = sharedWatched("isLoginRequired", @() !shouldDisableMenu && !isOfflineMenu)

let readyToFullLoadMask = LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED

return {
  loginState
  isProfileReceived = Computed(@() (loginState.get() & LOGIN_STATE.PROFILE_RECEIVED) != 0)
  isAuthorized = Computed(@() (loginState.get() & LOGIN_STATE.AUTHORIZED) != 0)
  isLoggedIn = Computed(@() (loginState.get() & LOGIN_STATE.LOGGED_IN) == LOGIN_STATE.LOGGED_IN)
  isReadyToFullLoad = Computed(@() (loginState.get() & readyToFullLoadMask) == readyToFullLoadMask)
  isLoginStarted = Computed(@() (loginState.get() & LOGIN_STATE.LOGIN_STARTED) != 0)
  isOnlineBinariesInited = Computed(@() (loginState.get() & LOGIN_STATE.ONLINE_BINARIES_INITED) != 0)
  isLoginRequired
}
