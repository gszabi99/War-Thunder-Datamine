local last_called_gui_testflight = null

return {
  set_last_called_gui_testflight = @(v) last_called_gui_testflight=v
  get_last_called_gui_testflight = @() last_called_gui_testflight != null
    ? freeze(last_called_gui_testflight)
    : last_called_gui_testflight
}
