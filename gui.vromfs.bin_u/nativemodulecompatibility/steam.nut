return {
  is_running = ::steam_is_running
  get_app_id = ::steam_get_app_id
  get_my_id = ::steam_get_my_id
  open_url = @(_) false
  is_overlay_enabled = @() false
  is_overlay_active = ::steam_is_overlay_active
  is_running_on_steam_deck = @() false
}
