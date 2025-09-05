module input_common
require WTInput

def toggle_shortcut(shortcut : string)
  activate_shortcut(shortcut, true, true)

def set_shortcut(shortcut : string; value : bool)
  activate_shortcut(shortcut, value, false)