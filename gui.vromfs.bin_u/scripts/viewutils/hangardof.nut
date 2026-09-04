from "vr" import is_stereo_mode
from "%scripts/dagui_library.nut" import *

let needUseHangarDof = @() is_stereo_mode()

return {
  needUseHangarDof
}