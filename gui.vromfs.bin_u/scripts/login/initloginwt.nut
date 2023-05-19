from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { g_script_reloader } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
local cachedLoginData = persist("cachedLoginData", @() { use_tencent_login = null, use_dmm_login = null })

foreach (fn in [
                 "login.nut"
                 "loginWnd.nut"
                 "steamLogin.nut"
                 "epicLogin.nut"
                 "ps4Login.nut"
                 "xboxOneLogin.nut"
                 "tencentLogin.nut"
                 "dmmLogin.nut"
                 "waitForLoginWnd.nut"
                 "updaterModal.nut"
                 "loginWT.nut"
               ])
  g_script_reloader.loadOnce($"%scripts/login/{fn}")

::use_tencent_login <- function use_tencent_login() {
  if (cachedLoginData.use_tencent_login == null) {
    cachedLoginData.use_tencent_login = is_platform_windows && ::getFromSettingsBlk("yunetwork/useTencentLogin", false)
  }
  return cachedLoginData.use_tencent_login
}

::use_dmm_login <- function use_dmm_login() {
  if (cachedLoginData.use_dmm_login == null) {
    cachedLoginData.use_dmm_login = ::dgs_get_argv("dmm_user_id") && ::dgs_get_argv("dmm_token")
  }
  return cachedLoginData.use_dmm_login
}
