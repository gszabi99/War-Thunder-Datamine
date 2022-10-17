#allow-root-table
return {
  activateShortcut = @(name, value, isSingle) ::activate_shortcut?(name)
  emulateShortcut = @(name) ::emulate_shortcut?(name)
  setAxisValue = @(name, value) ::set_axis_value?(name)
  setVirtualAxisValue = @(name, value) ::set_virtual_axis?(name)
  getDefaultPresetPath = @() ""
}
