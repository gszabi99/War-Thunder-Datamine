local function backToMainScene() {
  if (::is_in_flight())
    ::gui_start_flight_menu()
  else
    ::gui_start_mainmenu()
}

return backToMainScene

