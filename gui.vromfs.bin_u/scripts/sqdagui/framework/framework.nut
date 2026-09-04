from "%scripts/sqDagui/daguiNativeApi.nut" import *

foreach (fn in [
                 "msgBox.nut"
                 "baseGuiHandler.nut"
                 "baseGuiHandlerManager.nut"
                 "framedMessageBox.nut"
               ])
  require($"%scripts/sqDagui/framework/{fn}")
