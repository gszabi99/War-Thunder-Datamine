from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getRollIndicator = @() null, getIsVisibleRollIndicator = @() Watched(false) } = require("hudTankStates")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { abs } = require("math")

let iconedHintsConfig = [{
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
  esUnitType = ES_UNIT_TYPE_TANK
  updateConfigs = [{
    watch = getIsVisibleRollIndicator()
    updateFunc = @(obj, value) obj.show(value)
  }
  {
    watch = getRollIndicator()
    updateFunc = function(obj, value) {
      let { isCritical = false, rollAngle = 0 } = value
      obj.overlayTextColor = isCritical ? "bad" : "active"
      obj.findObject("hint_text").setValue(abs(rollAngle).tostring())
      obj.findObject("roll_indicator").rotation = rollAngle
    }
  }]
}]

let function initIconedHints(scene, esUnitType) {
  let hintsObj = scene.findObject("iconed_hints")
  if (!hintsObj?.isValid())
    return

  let blk = ::handyman.renderCached("%gui/hud/iconedHints.tpl", {
    iconedHints = iconedHintsConfig.filter(@(v) v.esUnitType == esUnitType)
      .map(@(v) {
        hintValue = stashBhvValueConfig(v.updateConfigs)
        hintIcons = v.hintIcons
      })
  })
  this.guiScene.replaceContentFromText(hintsObj, blk, blk.len(), this)
}

return {
  initIconedHints
}
