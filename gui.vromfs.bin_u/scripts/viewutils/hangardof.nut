from "%scripts/dagui_library.nut" import *

let { is_stereo_mode } = require("vr")

let needUseHangarDof = @() is_stereo_mode()

return {
  needUseHangarDof
}