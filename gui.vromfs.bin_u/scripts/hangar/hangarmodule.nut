from "%scripts/dagui_library.nut" import *
let { enable_blur, disable_blur } = require("rendering")

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