from "%scripts/dagui_library.nut" import *

let sizeDelayTimerPid = dagui_propid_add_name_id("_size_delay")
let { deferOnce } = require("dagor.workcycle")

let animTimerPid = dagui_propid_add_name_id("_transp-timer")

function updateCrewLifebar(obj, value, params = null) {
  let { minAliveCrewPercent = -1, needSkipAnim = false } = params

  let lifebar = obj.findObject("crew_lifebar")
  let fullWidth = lifebar?.isValid() ? lifebar.getParent().getSize()[0] : 0
  if (fullWidth == 0)
    return

  let lifebarRed = obj.findObject("crew_lifebar_lost")
  let prevValue = lifebar.width
  let nextValue = $"{value} * pw"

  if (!needSkipAnim) {
    let currentRedBarWidthPercent = (lifebarRed.getSize()[0] / fullWidth.tofloat())*100
    lifebarRed["width-base"] = currentRedBarWidthPercent.tostring()
    lifebarRed["width-end"] = (value * 100).tostring()
    lifebarRed.setFloatProp(sizeDelayTimerPid, 0.5)
    lifebarRed._blink = "yes"

    let lifebarFlash = obj.findObject("crew_lifebar_flash")
    lifebarFlash["width"] = prevValue
    lifebarFlash["_blink"] = "yes"
  } else {
    lifebarRed["width-base"] = (value * 100).tostring()
    lifebarRed["width-end"] = (value * 100).tostring()
    lifebarRed.width = nextValue
  }

  lifebar["width"] = nextValue

  if (minAliveCrewPercent >= 0) {
    let minCrewBarObj = obj.findObject("min_crew_bar")
    minCrewBarObj.width = $"{minAliveCrewPercent} * pw"
  }
}

function setCrewLostText(nest, lostVal, leftPos, needAddCount = false) {
  let animObj = nest.getChild(0)
  animObj.left = $"{leftPos/100.0*nest.getSize()[0]} - w/2"

  let textObj = animObj.getChild(0)
  if (needAddCount)
    lostVal = lostVal + to_integer_safe(textObj?.text, 0, false)
  textObj.setValue($"{lostVal}")
  textObj["color-factor"] = "255"

  deferOnce(function() {
    if (!textObj.isValid())
      return
    textObj.setFloatProp(animTimerPid, 0.0)
    textObj["_blink"] = "yes"
  })
}

return {
  updateCrewLifebar
  setCrewLostText
}