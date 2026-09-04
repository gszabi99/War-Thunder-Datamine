



import "dagui" as dagui
import "daguiScene" as daguiScene

let { get_button_name = @(...) null } = require_optional("guiScriptUtils") 

return freeze({
  get_button_name

  get_gui_scene = dagui.get_gui_scene
  get_cur_gui_scene = dagui.get_cur_gui_scene
  get_main_gui_scene = dagui.get_main_gui_scene
  dagui_propid_add_name_id = daguiScene.dagui_propid.add_name_id
  dagui_propid_get_name_id = daguiScene.dagui_propid.get_name_id
  screen_width = daguiScene.screen_width
  screen_height = daguiScene.screen_height
  set_dirpad_event_processed = daguiScene.set_dirpad_event_processed
  DaGuiObject = daguiScene.DaGuiObject
  is_mouse_last_time_used = daguiScene.is_mouse_last_time_used
}.__update(daguiScene))
