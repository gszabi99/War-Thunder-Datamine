return {
  activateShortcut = @(name, value, isSingle) ::activate_shortcut?(name)
  emulateShortcut = @(name) ::emulate_shortcut?(name)
}
