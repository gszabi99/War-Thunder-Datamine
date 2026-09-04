let gameRendObjs = require_optional("gameRendObjs")
let consttable = getconsttable()

let fields = [
  "ROBJ_XRAYDOLL",
  "ROBJ_HELICOPTER_HORIZONTAL_SPEED",
  "ROBJ_RADAR_GROUND_REFLECTIONS",
  "ROBJ_TACTICAL_MAP",
  "ROBJ_TACTICAL_CAMERA_RENDER",
  "ROBJ_RADAR",
  "ROBJ_HIT_CAMERA",
  "ROBJ_SCREEN_FADE",
  "ROBJ_UNIT_POSE_INDICATOR",
  "ROBJ_SENSOR_VIEW_INDICATORS",
  "ROBJ_CROSSHAIR_PREVIEW",
]

let export = {}
foreach (k in fields)
  export[k] <- gameRendObjs?[k] ?? consttable[k]

return freeze(export)
