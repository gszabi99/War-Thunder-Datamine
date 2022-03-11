local { getRollIndicator = @() null, getIsVisibleRollIndicator = @() ::Watched(false) } = require("hudTankStates")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")

local iconedHintsConfig = [{
  id = "roll_indicator"
  hintIcons = [{
    id = "roll_indicator"
    icon = "#ui/gameuiskin#vehicle_indicator.svg"
    iconWidth = "pw"
  },
  {
    icon = "#ui/gameuiskin#circle_indicator.svg"
    iconWidth = "pw"
  }]
  esUnitType = ::ES_UNIT_TYPE_TANK
  updateConfigs = [{
    watch = getIsVisibleRollIndicator()
    updateFunc = @(obj, value) obj.show(value)
  }
  {
    watch = getRollIndicator()
    updateFunc = function(obj, value) {
      local { isCritical = false, rollAngle = 0 } = value
      obj.overlayTextColor = isCritical ? "bad" : "active"
      obj.findObject("hint_text").setValue(::abs(rollAngle).tostring())
      obj.findObject("roll_indicator").rotation = rollAngle
    }
  }]
}]

local function initIconedHints(scene, esUnitType) {
  local hintsObj = scene.findObject("iconed_hints")
  if (!hintsObj?.isValid())
    return

  local blk = ::handyman.renderCached("gui/hud/iconedHints", {
    iconedHints = iconedHintsConfig.filter(@(v) v.esUnitType == esUnitType)
      .map(@(v) {
        hintValue = stashBhvValueConfig(v.updateConfigs)
        hintIcons = v.hintIcons
      })
  })
  guiScene.replaceContentFromText(hintsObj, blk, blk.len(), this)
}

return {
  initIconedHints
}
