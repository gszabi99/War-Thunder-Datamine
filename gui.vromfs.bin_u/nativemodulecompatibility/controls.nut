#allow-root-table
return {
  activateShortcut = @(name, _value, _isSingle) getroottable()?["activate_shortcut"](name)
  emulateShortcut = @(name) getroottable()?["emulate_shortcut"](name)
  setAxisValue = @(name, _value) getroottable()?["set_axis_value"](name)
  setVirtualAxisValue = @(name, _value) getroottable()?["set_virtual_axis"](name)
  getDefaultPresetPath = @() ""
}
