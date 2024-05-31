from "%scripts/dagui_library.nut" import *

let { setChardToken } = require("chard")
let { getPlayerTokenGlobal } = require("auth_wt")
let contacts = require("contacts")
let { get_time_msec } = require("dagor.time")
let { resetTimeout } = require("dagor.workcycle")
let logC = log_with_prefix("[CONTACTS] ")
let { APP_ID } = require("app")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let charClientEvent = require("%scripts/charClientEvent.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

const CONTACTS_GAME_ID = "wt"

const RETRY_LOGIN_MSEC = 60000

let isLoggedIntoContacts = hardPersistWatched("isLoggedIntoContacts", false)
let lastLoginErrorTime = hardPersistWatched("lastLoginErrorTime", -1)

let { request, registerHandler } = charClientEvent("contacts", contacts)

registerHandler("cln_cs_login", function(result) {
  if (!::g_login.isLoggedIn()) {
    logC("Ignore login cb because of not auth")
    return
  }

  // On success, it is in "result", on error it is in "result.result"
  if ("result" in result)
    result = result.result

  let isSuccess = !result?.error
  isLoggedIntoContacts(isSuccess)
  lastLoginErrorTime(isSuccess ? -1 : get_time_msec())
  if (!isSuccess) {
    logC("Login cb error: ", result?.error)
    return
  }

  logC("Login success")
  setChardToken(result?.chardToken ?? 0)
})

function loginContacts() {
  if (isLoggedIntoContacts.value || !::g_login.isLoggedIn())
    return

  logC("Login request")
  request("cln_cs_login",
    {
      headers = { token = getPlayerTokenGlobal(), appid = APP_ID },
      data = { game = CONTACTS_GAME_ID }
    })
}

addListenersWithoutEnv({
  SignOut = @(_) isLoggedIntoContacts(false)
  LoginComplete = @(_) loginContacts()
})

if (!isLoggedIntoContacts.value) {
  let timeLeft = lastLoginErrorTime.value <= 0 ? 0
    : lastLoginErrorTime.value + RETRY_LOGIN_MSEC - get_time_msec()
  if (timeLeft <= 0)
    loginContacts()
  else
    resetTimeout(0.001 * timeLeft, loginContacts)
}
lastLoginErrorTime.subscribe(function(t) {
  if (t > 0)
    resetTimeout(0.001 * RETRY_LOGIN_MSEC, loginContacts)
})
