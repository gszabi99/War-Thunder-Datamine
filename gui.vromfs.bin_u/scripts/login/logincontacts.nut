import "contacts" as contacts
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "auth_wt" import getPlayerTokenGlobal
from "dagor.time" import get_time_msec
from "dagor.workcycle" import resetTimeout
from "app" import APP_ID
from "%sqstd/globalState.nut" import hardPersistWatched
from "%scripts/dagui_library.nut" import *

let logC = log_with_prefix("[CONTACTS] ")
let charClientEvent = require("%scripts/charClientEvent.nut")

const CONTACTS_GAME_ID = "wt"

const RETRY_LOGIN_MSEC = 60000

let isLoggedIntoContacts = hardPersistWatched("isLoggedIntoContacts", false)
let lastLoginErrorTime = hardPersistWatched("lastLoginErrorTime", -1)

let { request, registerHandler } = charClientEvent("contacts", contacts)

registerHandler("cln_cs_login", function(result) {
  if (!isLoggedIn.get()) {
    logC("Ignore login cb because of not auth")
    return
  }

  
  if ("result" in result)
    result = result.result

  let isSuccess = !result?.error
  isLoggedIntoContacts.set(isSuccess)
  lastLoginErrorTime.set(isSuccess ? -1 : get_time_msec())
  if (!isSuccess) {
    logC("Login cb error: ", result?.error)
    return
  }

  logC("Login success")
  
})

function loginContacts() {
  if (isLoggedIntoContacts.get() || !isLoggedIn.get())
    return

  local data = { game = CONTACTS_GAME_ID }

  foreach (name in ["operatorName", "publisher"]) {
    local val = getCurCircuitOverride(name)
    if (val != null) {
      data[name] <- val
    }
  }

  logC("Login request", data)
  request("cln_cs_login",
    {
      headers = { token = getPlayerTokenGlobal(), appid = APP_ID },
      data
    })
}

addListenersWithoutEnv({
  SignOut = @(_) isLoggedIntoContacts.set(false)
  LoginComplete = @(_) loginContacts()
})

if (!isLoggedIntoContacts.get()) {
  let timeLeft = lastLoginErrorTime.get() <= 0 ? 0
    : lastLoginErrorTime.get() + RETRY_LOGIN_MSEC - get_time_msec()
  if (timeLeft <= 0)
    loginContacts()
  else
    resetTimeout(0.001 * timeLeft, loginContacts)
}
lastLoginErrorTime.subscribe(function(t) {
  if (t > 0)
    resetTimeout(0.001 * RETRY_LOGIN_MSEC, loginContacts)
})
