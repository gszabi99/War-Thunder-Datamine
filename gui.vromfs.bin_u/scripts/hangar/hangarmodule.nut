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
      params?.nearFrom ?? 0, 
      params?.nearTo ?? 0, 
      params?.nearEffect ?? 0, 
      params?.farFrom ?? 0, 
      params?.farTo ?? 0.1, 
      params?.farEffect ?? 1) 
  }
  else
    disable_dof()
}

return {
  blurHangar
}