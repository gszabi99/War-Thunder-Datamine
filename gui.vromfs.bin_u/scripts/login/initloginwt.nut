from "%scripts/dagui_natives.nut" import dgs_get_argv
from "%scripts/dagui_library.nut" import *

let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
local cachedLoginData = persist("cachedLoginData", @() { use_dmm_login = null })

foreach (fn in [
                 "login.nut"
                 "loginWnd.nut"
                 "steamLogin.nut"
                 "epicLogin.nut"
                 "samsungLogin.nut"
                 "ps4Login.nut"
                 "xboxOneLogin.nut"
                 "dmmLogin.nut"
                 "waitForLoginWnd.nut"
                 "updaterModal.nut"
                 "loginWT.nut"
               ])
  loadOnce($"%scripts/login/{fn}")

::use_dmm_login <- function use_dmm_login() {
  if (cachedLoginData.use_dmm_login == null) {
    cachedLoginData.use_dmm_login = dgs_get_argv("dmm_user_id") && dgs_get_argv("dmm_token")
  }
  return cachedLoginData.use_dmm_login
}
