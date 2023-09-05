let gui_handlers = {}
let function register_gui_handler(key, handler){
  gui_handlers[key] <- handler
}

return { gui_handlers, register_gui_handler}