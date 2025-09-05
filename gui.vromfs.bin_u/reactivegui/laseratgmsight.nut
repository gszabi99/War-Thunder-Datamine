from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { turretAngles } = require("%rGui/airHudElems.nut")
let lineWidth = hdpx(LINE_WIDTH)
let { LaserAtgmSightColor, LaserAgmName, LaserAgmCnt, LaserAgmSelectedCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { GuidanceLockState } = require("%rGui/agmAimState.nut")
let { IsOnGround } = require("%rGui/planeState/planeToolsState.nut")
let { hudFontHgt, fontOutlineColor, fontOutlineFxFactor } = require("%rGui/style/airHudStyle.nut")
let { GuidanceLockResult } = require("guidanceConstants")


let crosshair = @() {
  size = ph(10)
  pos = [pw(50), ph(50)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = LaserAtgmSightColor.get()
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
      size = static [100, SIZE_TO_CONTENT]
      watch = GuidanceLockState
      rendObj = ROBJ_TEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      hplace = ALIGN_LEFT
      padding = static [0, 20]
      text = GuidanceLockState.value == GuidanceLockResult.RESULT_INVALID ? ""
        : (GuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY ? loc("HUD/TXT_STANDBY")
        : (GuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP ? loc("HUD/TXT_WARM_UP")
        : (GuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING ? loc("HUD/TXT_LOCK")
        : (GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING ? loc("HUD/TXT_TRACK")
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
      text = LaserAgmSelectedCnt.get() > 0
        ? string.format("%d/%d", LaserAgmCnt.get(), LaserAgmSelectedCnt.get())
        : LaserAgmCnt.get().tostring()
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
      text = string.format("   %s", loc(LaserAgmName.get()))
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
      color = LaserAtgmSightColor.get()
      text = IsOnGround.get() ? loc("HUD/TXT_ROCKETS_LAUNCH_IMPOSSIBLE")
        : GuidanceLockState.value == 2 ? loc("hints/need_lock_laser_spot")
        : (GuidanceLockState.value == 3 ? loc("hints/click_for_launch_laser_shell") : "")
    }
  ]
}

function Root(width, height) {
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