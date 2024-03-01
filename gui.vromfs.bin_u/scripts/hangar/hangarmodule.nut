from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import enable_dof, disable_dof

function canBlurHangar() {
  return ("enable_dof" in getroottable())
}

function blurHangar(enable, params = null) {
  if (!canBlurHangar())
    return

  if (enable) {
    enable_dof(
      params?.nearFrom ?? 0, // meters
      params?.nearTo ?? 0, // meters
      params?.nearEffect ?? 0, // 0..1
      params?.farFrom ?? 0, // meters
      params?.farTo ?? 0.1, // meters
      params?.farEffect ?? 1) // 0..1
  }
  else
    disable_dof()
}

return {
  blurHangar
}