//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let sessionsListBlkPath = Watched("%gui/sessionsList.blk")

return {
  sessionsListBlkPath = sessionsListBlkPath
}