from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { turretAngles } = require("airHudElems.nut")
let lineWidth = hdpx(LINE_WIDTH)
let { LaserAtgmSightColor, LaserAgmName, LaserAgmCnt, LaserAgmSelectedCnt } = require("planeState/planeWeaponState.nut")
let { GuidanceLockState } = require("agmAimState.nut")
let { IsOnGround } = require("planeState/planeToolsState.nut")
let { hudFontHgt, fontOutlineColor, fontOutlineFxFactor } = require("style/airHudStyle.nut")


let crosshair = @() {
  size = [ph(10), ph(10)]
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = LaserAtgmSightColor.value
  lineWidth = lineWidth * 3
  commands = [
    [VECTOR_LINE, -100, 0, -20, 0],
    [VECTOR_LINE, 20, 0, 100, 0],
    [VECTOR_LINE, 0, -100, 0, -20],
    [VECTOR_LINE, 0, 20, 0, 100],
    [VECTOR_LINE, 0, 0, 0, 0]
  ]
}

let status = @() {
  size = flex()
  pos = [pw(2), ph(5)]
  flow = FLOW_HORIZONTAL
  children = [
    @() {
      size = SIZE_TO_CONTENT
      watch = LaserAgmName
      rendObj = ROBJ_TEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      text = loc("HUD/TXT_AGM_SHORT")
    },
    @() {
      size = [100, SIZE_TO_CONTENT]
      watch = GuidanceLockState
      rendObj = ROBJ_TEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      hplace = ALIGN_LEFT
      padding = [0, 20]
      text = GuidanceLockState.value == -1 ? ""
        : (GuidanceLockState.value == 0 ? loc("HUD/TXT_STANDBY")
        : (GuidanceLockState.value == 1 ? loc("HUD/TXT_WARM_UP")
        : (GuidanceLockState.value == 2 ? loc("HUD/TXT_LOCK")
        : (GuidanceLockState.value == 3 ? loc("HUD/TXT_TRACK")
        : loc("HUD/TXT_LOCK_AFTER_LAUNCH")))))
    },
    @() {
      size = SIZE_TO_CONTENT
      watch = [LaserAgmCnt, LaserAgmSelectedCnt]
      rendObj = ROBJ_TEXT
      hplace = ALIGN_LEFT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      text = LaserAgmSelectedCnt.value > 0
        ? string.format("%d/%d", LaserAgmCnt.value, LaserAgmSelectedCnt.value)
        : LaserAgmCnt.value.tostring()
    },
    @() {
      size = SIZE_TO_CONTENT
      watch = LaserAgmName
      rendObj = ROBJ_TEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      text = string.format("   %s", loc(LaserAgmName.value))
    },
  ]
}

let hints = @() {
  size = flex()
  children = [
    @() {
      watch = [GuidanceLockState, IsOnGround]
      size = flex()
      pos = [pw(42), ph(70)]
      rendObj = ROBJ_TEXT
      font = Fonts.hud
      fontSize = hudFontHgt
      color = LaserAtgmSightColor.value
      text = IsOnGround.value ? loc("HUD/TXT_ROCKETS_LAUNCH_IMPOSSIBLE")
        : GuidanceLockState.value == 2 ? loc("hints/need_lock_laser_spot")
        : (GuidanceLockState.value == 3 ? loc("hints/click_for_launch_laser_shell") : "")
    }
  ]
}

let function Root(width, height) {
  return {
    size = [width, height]
    children = [
      crosshair,
      status,
      hints,
      turretAngles(LaserAtgmSightColor, hdpx(150), hdpx(150), sw(50), sh(90))
    ]
  }
}

return Root