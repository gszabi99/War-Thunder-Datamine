local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { startLogout } = require("scripts/login/logout.nut")
local {
  resetMultiplayerPrivilege,
  updateMultiplayerPrivilege
} = require("scripts/user/xboxFeatures.nut")

addListenersWithoutEnv({
  SignOut = @(p) resetMultiplayerPrivilege()
  XboxSystemUIReturn = @(p) updateMultiplayerPrivilege()
  LoginComplete = @(p) updateMultiplayerPrivilege()
})

::xbox_on_start_logout <- startLogout