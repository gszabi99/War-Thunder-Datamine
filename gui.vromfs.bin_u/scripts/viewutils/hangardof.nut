local { is_stereo_mode } = ::require_native("vr")

local needUseHangarDof = @() is_stereo_mode()

return {
  needUseHangarDof
}