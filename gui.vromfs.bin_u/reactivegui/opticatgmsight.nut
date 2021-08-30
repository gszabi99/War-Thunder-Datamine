local {Roll, TurretYaw, TurretPitch} = require("planeState.nut")
local {TrackerVisible, TrackerAngle} = require("agmAimState.nut")
local lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)

local opticColor = Color(255, 255, 255)
local crosshair = @() {
  watch = TrackerVisible
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  color = opticColor
  lineWidth = lineWidth * 2
  commands = [
    [VECTOR_LINE, 50, 0, 50, TrackerVisible.value ? 49 : 40],
    [VECTOR_LINE, 0, 50, TrackerVisible.value ? 49 : 40, 50],
    [VECTOR_LINE, TrackerVisible.value ? 51 : 60, 50, 100, 50],
    [VECTOR_LINE, 50, TrackerVisible.value ? 51 : 54, 50, 100],
    [VECTOR_LINE, 48, 55, 52, 55],
    [VECTOR_LINE, 48, 60, 52, 60],
    [VECTOR_LINE, 48, 65, 52, 65],
  ]
}

local rollIndicator = @() {
  size = [ph(15), ph(15)]
  pos = [0, ph(85)]
  children = [
    {
      size = flex()
      rendObj = ROBJ_SOLID
      color = Color(0, 0, 0)
    },
    @() {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = opticColor
      fillColor = Color(0, 0, 0)
      lineWidth = lineWidth * 3
      commands = [
        [VECTOR_SECTOR, 50, 50, 42, 42, 0, 180],
        [VECTOR_LINE, 1, 50, 8, 50],
        [VECTOR_LINE, 92, 50, 99, 50]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.value.tointeger()
          pivot = [0.5, 0.5]
        }
      }
    },
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = opticColor
      fillColor = Color(0, 0, 0)
      lineWidth = lineWidth * 3
      commands = [
        [VECTOR_ELLIPSE, 50, 50, 5, 5],
        [VECTOR_LINE, 15, 50, 45, 50],
        [VECTOR_LINE, 55, 50, 85, 50],
        [VECTOR_LINE, 50, 45, 50, 35]
      ]
    }
  ]
}

local lockZoneVisible = Computed(@() TrackerAngle.value != 0.0)
local lockZone = @() {
  size = flex()
  watch = lockZoneVisible
  children = [ lockZoneVisible.value ?
    @() {
      watch = [TurretYaw, TurretPitch]
      size = [ph(5), ph(5)]
      rendObj = ROBJ_VECTOR_CANVAS
      pos = [pw(50 + TurretYaw.value / TrackerAngle.value * 2), ph(50 - TurretPitch.value / TrackerAngle.value * 15)]
      color = opticColor
      lineWidth = lineWidth * 2
      commands = [
        [VECTOR_LINE, -100, 0, 100, 0],
        [VECTOR_LINE, 0, -100, 0, 100]
      ]
    } : null
  ]
}

local function Root(width, height, posX = 0, posY = 0) {
  return {
    pos = [posX, posY]
    size = [width, height]
    children = [crosshair, rollIndicator, lockZone]
  }
}

return Root