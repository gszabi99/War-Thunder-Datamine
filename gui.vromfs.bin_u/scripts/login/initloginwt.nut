from "%scripts/dagui_library.nut" import *

let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

foreach (fn in [
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
