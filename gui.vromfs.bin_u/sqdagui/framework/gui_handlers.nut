from "%sqDagui/daguiNativeApi.nut" import *
let { dynamic_content } = require("%sqstd/analyzer.nut")

let gui_handlers = dynamic_content({})
function register_gui_handler(key, handler){
  gui_handlers[key] <- handler
}

return { gui_handlers, register_gui_handler}