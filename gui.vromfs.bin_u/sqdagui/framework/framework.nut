let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

foreach (fn in [
                 "msgBox.nut"
                 "baseGuiHandler.nut"
                 "baseGuiHandlerManager.nut"
                 "framedMessageBox.nut"
               ])
  loadOnce($"%sqDagui/framework/{fn}")

::open_url_by_obj <- require("open_url_by_obj.nut").open_url_by_obj


