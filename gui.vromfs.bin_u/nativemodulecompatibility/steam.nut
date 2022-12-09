#allow-root-table
return {
  is_running = getroottable()["steam_is_running"]
  get_app_id = getroottable()["steam_get_app_id"]
  get_my_id = getroottable()["steam_get_my_id"]
  open_url = @(_) false
  is_overlay_enabled = @() false
  is_overlay_active = getroottable()["steam_is_overlay_active"]
  is_running_on_steam_deck = @() false
}
