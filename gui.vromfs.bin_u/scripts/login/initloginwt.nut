from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

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
  ::g_script_reloader.loadOnce("%scripts/login/" + fn)

::use_tencent_login <- function use_tencent_login() {
  return is_platform_windows && ::getFromSettingsBlk("yunetwork/useTencentLogin", false)
}

::use_dmm_login <- function use_dmm_login() {
  return ::dgs_get_argv("dmm_user_id") && ::dgs_get_argv("dmm_token")
}
