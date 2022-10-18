let { is_stereo_mode } = ::require_native("vr")

let needUseHangarDof = @() is_stereo_mode()

return {
  needUseHangarDof
}