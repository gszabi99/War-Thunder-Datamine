let app = require("%xboxLib/impl/app.nut")


return {
  XO_E_SYSTEM_UPDATE_REQUIRED = 0x8015DC01
  XO_E_CONTENT_UPDATE_REQUIRED = 0x8015DC02
  register_important_live_error_callback = app.register_important_live_error_callback
}