local function getLocalizedShortcutName(shortcutId) {
  return ::loc($"hotkeys/{shortcutId}")
}

return {
  getLocalizedShortcutName = getLocalizedShortcutName
}