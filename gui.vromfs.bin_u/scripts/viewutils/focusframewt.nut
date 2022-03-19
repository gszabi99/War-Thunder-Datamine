local focusFrame = require("sqDagui/focusFrame/focusFrame.nut")
local stdMath = require("std/math.nut")

local sizeProps = [
  ["width-base", "width-end"],
  ["height-base", "height-end"]
]

local animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

local baseTransparency = "30"
focusFrame.setHideTgtImageTimeMsec(200)

focusFrame.setAnimFunction(function(animObj, curTgt, prevTgt)
{
  local offsetMax = ::g_dagui_utils.toPixels(animObj.getScene(), "@focusFrameAnimOffsetMax")
  local offset = offsetMax
  if (prevTgt)
  {
    local offsetMin = ::g_dagui_utils.toPixels(animObj.getScene(), "@focusFrameAnimOffsetMin")
    local sh = ::screen_height()
    local minSh = 0.2 * sh
    local dist = ::max(::abs(prevTgt.pos[0] - curTgt.pos[0]), ::abs(prevTgt.pos[1] - curTgt.pos[1]))
    dist = ::clamp(dist, minSh, sh)
    offset = stdMath.lerp(minSh, sh, offsetMin, offsetMax, dist)
  }
  foreach(axis, sizeProp in sizeProps)
  {
    animObj[sizeProp[0]] = (curTgt.size[axis] + 2 * offset).tostring()
    animObj[sizeProp[1]] = curTgt.size[axis].tostring()
  }
  animObj.width = (curTgt.size[0] + 2 * offset).tostring()
  animObj.height = (curTgt.size[1] + 2 * offset).tostring()

  animObj["transp-base"] = baseTransparency
  animObj["color-factor"] = baseTransparency
  animObj.setFloatProp(animTimerPid, 0.0)
})

return focusFrame