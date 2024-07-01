from "%sqDagui/daguiNativeApi.nut" import *

foreach (fn in [
                 "msgBox.nut"
                 "baseGuiHandler.nut"
                 "baseGuiHandlerManager.nut"
                 "framedMessageBox.nut"
               ])
  require($"%sqDagui/framework/{fn}")
