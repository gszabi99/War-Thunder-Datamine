/**
 * Back caompatible only for daGUI, because old version can work only with string
 * representation of color in format "#AARRGGBB". daRg can't use old API because
 * it use integer instead of string to store color.
 */
return {
  correctHueTarget = @(color, target) color
  correctColorLightness = @(color, lightness) color
  TARGET_HUE_ALLY = getroottable()?.TARGET_HUE_ALLY ?? 0
  TARGET_HUE_SQUAD = getroottable()?.TARGET_HUE_SQUAD ?? 1
  TARGET_HUE_ENEMY = getroottable()?.TARGET_HUE_ENEMY ?? 2
  TARGET_HUE_SPECTATOR_ALLY = getroottable()?.TARGET_HUE_SPECTATOR_ALLY ?? 3
  TARGET_HUE_SPECTATOR_ENEMY = getroottable()?.TARGET_HUE_SPECTATOR_ENEMY ?? 4
  TARGET_HUE_RELOAD = 5
  TARGET_HUE_RELOAD_DONE = 6
  TARGET_HUE_HELICOPTER_HUD = 7
  TARGET_HUE_HELICOPTER_HUD_ALERT = 8
}
