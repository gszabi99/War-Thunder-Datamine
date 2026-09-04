from "rendering" import enable_blur, disable_blur
from "%scripts/dagui_library.nut" import *

function blurHangar(enable) {
  if (enable) {
    enable_blur()
  }
  else {
    disable_blur()
  }
}

return {
  blurHangar
}