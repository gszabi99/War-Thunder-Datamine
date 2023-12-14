//pseudo-module for native code
//this is 'api-like' for native dagui functions. And, in the same time, it is stub
let r = getroottable()

return {
  is_app_active = r?["is_app_active"] ?? @() true
  steam_is_overlay_active = r?["steam_is_overlay_active"] ?? @() false
  get_gui_scene = r?["get_gui_scene"] ?? @() null
  get_cur_gui_scene = r?["get_cur_gui_scene"] ?? @() null
  get_main_gui_scene = r?["get_main_gui_scene"] ?? @() null
//  get_scene_objects_under_cursor = r?["get_scene_objects_under_cursor"] ?? @() null
  get_dagui_mouse_cursor_pos = r?["get_dagui_mouse_cursor_pos"] ?? @(...) ""
  get_dagui_mouse_cursor_pos_RC = r?["get_dagui_mouse_cursor_pos_RC"] ?? @(...) ""
  get_dagui_post_include_css_str = r?["get_dagui_post_include_css_str"] ?? @(...) ""
  set_dagui_post_include_css_str = r["set_dagui_post_include_css_str"] ?? @(...) ""
  get_dagui_pre_include_css_str = r?["get_dagui_pre_include_css_str"] ?? @(...) ""
  set_dagui_pre_include_css = r?["set_dagui_pre_include_css"] ?? @(...) ""
  dagui_propid_add_name_id = r?["dagui_propid"].add_name_id ?? @(_id) null
  dagui_propid_get_name_id = r?["dagui_propid"].get_name_id ?? @(_id) null
  set_script_gui_behaviour_events = r?["set_script_gui_behaviour_events"] ?? @(...) ""
  replace_script_gui_behaviour = r?["replace_script_gui_behaviour"] ?? @(...) ""
  add_script_gui_behaviour = r?["add_script_gui_behaviour"] ?? @(...) ""
  screen_width = r?["screen_width"] ?? @() 1024
  screen_height = r?["screen_height"] ?? @() 768
  set_dirpad_event_processed = r?["set_dirpad_event_processed"] ?? @(...) null
  del_script_gui_behaviour_events = r?["del_script_gui_behaviour_events"] ?? @(...) ""
  get_button_name = r?["get_button_name"] ?? @(...) null
}
