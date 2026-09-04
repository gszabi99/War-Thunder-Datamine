from "dagor.debug" import logerr
from "%scripts/sqDagui/daguiNativeApi.nut" import *



let gui_handlers = {}

function register_gui_handler(key:string, handler:class) {
  gui_handlers[key] <- handler
}

let missingLogged = {}
function get_gui_handler(name) {
  if (name in gui_handlers)
    return gui_handlers[name]
  else if (name not in missingLogged) {
    missingLogged[name] <- true
    logerr($"gui_handlers: no handler registered for '{name}'")
  }
  return null
}

let has_gui_handler = @(name) name in gui_handlers



function is_gui_handler_instance(handler, name:string) {
  let hClass = gui_handlers?[name]
  return hClass != null && handler instanceof hClass
}


function find_gui_handler_name(handlerClass) {
  foreach (name, hClass in gui_handlers)
    if (hClass == handlerClass)
      return name
  return null
}


function each_gui_handler(func:function) {
  foreach (name, hClass in gui_handlers)
    func(name, hClass)
}

return {
  register_gui_handler
  get_gui_handler
  has_gui_handler
  is_gui_handler_instance
  find_gui_handler_name
  each_gui_handler
}
