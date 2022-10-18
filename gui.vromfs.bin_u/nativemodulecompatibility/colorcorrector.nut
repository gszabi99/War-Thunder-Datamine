/**
 * Back caompatible only for daGUI, because old version can work only with string
 * representation of color in format "#AARRGGBB". daRg can't use old API because
 * it use integer instead of string to store color.
 */
return {
  correctHueTarget = @(color, _target) color
  correctColorLightness = @(color, _lightness) color
  TARGET_HUE_ALLY = getconsttable()?.TARGET_HUE_ALLY ?? 0
  TARGET_HUE_SQUAD = getconsttable()?.TARGET_HUE_SQUAD ?? 1
  TARGET_HUE_ENEMY = getconsttable()?.TARGET_HUE_ENEMY ?? 2
  TARGET_HUE_SPECTATOR_ALLY = getconsttable()?.TARGET_HUE_SPECTATOR_ALLY ?? 3
  TARGET_HUE_SPECTATOR_ENEMY = getconsttable()?.TARGET_HUE_SPECTATOR_ENEMY ?? 4
  TARGET_HUE_RELOAD = 5
  TARGET_HUE_RELOAD_DONE = 6

  TARGET_HUE_HELICOPTER_CROSSHAIR = 7
  TARGET_HUE_HELICOPTER_HUD = 8
  TARGET_HUE_HELICOPTER_PARAM_HUD = 9
  TARGET_HUE_HELICOPTER_MFD = 10

  TARGET_HUE_AIRCRAFT_HUD = 11
  TARGET_HUE_AIRCRAFT_PARAM_HUD = 12

  TARGET_HUE_HELICOPTER_HUD_ALERT_LOW = 13
  TARGET_HUE_HELICOPTER_HUD_ALERT_MEDIUM = 14
  TARGET_HUE_HELICOPTER_HUD_ALERT_HIGH = 15
  TARGET_HUE_AIRCRAFT_HUD_ALERT_LOW = 16
  TARGET_HUE_AIRCRAFT_HUD_ALERT_MEDIUM = 17
  TARGET_HUE_AIRCRAFT_HUD_ALERT_HIGH = 18

  TARGET_HUE_ARBITER_HUD = 19

  setAlertAircraftHues = @(_v1, _v2, _v3, _index) null
  setAlertHelicopterHues = @(_v1, _v2, _v3, _index) null
  getAlertAircraftHues = @() -1
  getAlertHelicopterHues = @() -1
  setHsb = @(_target, _hue, _sat, _bri) null
}
