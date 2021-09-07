local { turretAngles } = require("airHudElems.nut")
local lineWidth = hdpx(LINE_WIDTH)
local { LaserAtgmSightColor, LaserAgmName, LaserAgmCnt } = require("planeState.nut")
local { GuidanceLockState } = require("agmAimState.nut")
local {hudFontHgt, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")


local crosshair = @() {
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

local status = @() {
  size = flex()
  pos = [pw(2), ph(5)]
  flow = FLOW_HORIZONTAL
  children = [
    @() {
      size = SIZE_TO_CONTENT
      watch = LaserAgmName
      rendObj = ROBJ_DTEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      text = ::loc("HUD/TXT_AGM_SHORT")
    },
    @() {
      size = [100, SIZE_TO_CONTENT]
      watch = GuidanceLockState
      rendObj = ROBJ_DTEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      hplace = ALIGN_LEFT
      padding = [0, 20]
      text = GuidanceLockState.value == -1 ? "" : (GuidanceLockState.value == 0 ? ::loc("HUD/TXT_STANDBY") : (GuidanceLockState.value == 1 ? ::loc("HUD/TXT_WARM_UP") : (GuidanceLockState.value == 2 ? ::loc("HUD/TXT_LOCK") : (GuidanceLockState.value == 3 ? ::loc("HUD/TXT_TRACK") : ::loc("HUD/TXT_LOCK_AFTER_LAUNCH")))))
    },
    @() {
      size = SIZE_TO_CONTENT
      watch = LaserAgmCnt
      rendObj = ROBJ_DTEXT
      hplace = ALIGN_LEFT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      text = LaserAgmCnt.value.tostring()
    },
    @() {
      size = SIZE_TO_CONTENT
      watch = LaserAgmName
      rendObj = ROBJ_DTEXT
      font = Fonts.hud
      fontFxColor = fontOutlineColor
      fontFxFactor = fontOutlineFxFactor
      fontFx = FFT_GLOW
      fontSize = hudFontHgt
      text = string.format("   %s", ::loc(LaserAgmName.value))
    },
  ]
}

local hints = @() {
  size = flex()
  children = [
    @() {
      watch = GuidanceLockState
      size = flex()
      pos = [pw(42), ph(70)]
      rendObj = ROBJ_DTEXT
      font = Fonts.hud
      fontSize = hudFontHgt
      color = LaserAtgmSightColor.value
      text = GuidanceLockState.value == 2 ? ::loc("hints/need_lock_laser_spot") : (GuidanceLockState.value == 3 ? ::loc("hints/click_for_launch_laser_shell") : "")
    }
  ]
}

local function Root(width, height) {
  return {
    size = [width, height]
    children = [
      crosshair,
      status,
      hints,
      turretAngles(LaserAtgmSightColor, hdpx(150), hdpx(150), sw(50), sh(90), false)
    ]
  }
}

return Root