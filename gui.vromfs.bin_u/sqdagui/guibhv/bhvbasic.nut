//version by 27.01.2011
//works only when time = 0..1,
// func(0) = 0,  func(1) = 1

::defaultScreenSize <- [1280, 720]
local sin = ::sin
local cos = ::cos
local fabs = ::fabs

::basicFunction <- function basicFunction(funcName, time) { //time >= -1, time <= 1
  if (time < 0)
    time = -time
//    return 1.0 - basicFunction(funcName, 1.0 + time)

  local t = time
  if (t > 1) t = 1.0

  switch(funcName) {
    case "square":           return t*t
    case "squareInv":        return 1.0 - (1.0-time) * (1.0-time)
    case "delayedSquareInv": return t < 0.5 ? 1.0 - (1.0 - time * 2) * (1.0 - time * 2) : 1.0
    case "squareSym":        return (t <= 0.5)? 2*t*t : 1.0 - 2*(1.0-time)*(1.0-time)
    case "cube":             return t*t*t
    case "cubeInv":          return 1.0 - (1.0-time) * (1.0-time) * (1.0-time)

    case "elastic":          return ((t < 0.25)? basicFunction("square", 4.0 * t) : 1.0) +
                                    (1.0 - t) * sin(basicFunction("square", t) * 2.0 * ::PI)
    case "elasticSmall":     return ((t < 0.25)? basicFunction("square", 4.0 * t) : 1.0) +
                                    0.1 * (1.0 - t) * sin(basicFunction("square", t) * 2.0 * ::PI)

    case "delayed_square":   return (t <= 0.5)? 0 : 4.0*(t - 0.5)*(t - 0.5)
    case "projector":        return (t%(1.0/80)) * 80
    case "doubleCos":        return 0.5 + 0.5 * cos(4.0 * t * ::PI)

    //cycled function
    case "doubleBlink":      return 0.5 - 0.5 * cos(4 * ::PI * t)
    case "blink":            return (t < 0.1)? 10.0*t : 1.0 - (t-0.1)/0.9
    case "sin":              return 0.5 + 0.5 * sin((t * 2.0 - 0.5) * ::PI)

    case "delayed":          return (t > 0.25) ? 1.0 : 4.0*t
    case "delayedInv":       return (t > 0.75) ? 0.0 : 4.0*(t - 0.75)

    case "blinkSin":
      local val = (t < 0.1)? 10.0*t : 1.0 - (t-0.1)/0.9
      if (t < 0.5)
        val *= 0.75 + 0.25 * sin((t * 80.0 - 0.5) * ::PI)
      return val

    case "blinkCos":
      local val = (t < 0.1)? 10.0*t : 1.0 - (t-0.1)/0.9
      if (t < 0.5)
        val *= 0.75 + 0.25 * cos((t * 40.0 - 0.5) * ::PI)
      return val

    case "rouletteCubicBezier":
      return ::cubic_bezier_solver.solve(t, 0.16, 0, 0.0, 1.0)
    case "rouletteCubicBezierBackFunc":
      return 1-::cubic_bezier_solver.solve(1-t, 0.55,0,0.32,1.42)

    default:              return t  //linear
  }
}

::blendProp <- function blendProp(curX, newX, blendTime, dt) {
  if ((blendTime <= 0) || (fabs(newX - curX) < 1))
    return newX

  local blendK = 4.0 * dt / blendTime
  local dX = (newX - curX) * blendK
  if (fabs(dX) < 1)
    dX = (dX < 0)? -1 : 1
  return (blendK > 1)? newX : curX + dX
}

class gui_bhv_deprecated.basicSize
{
  timerName = "_size-timer"
  timerPID = ::dagui_propid.add_name_id("_size-timer")

  function onAttach(obj)
  {
    if (obj.getFloatProp(timerPID, -1) < 0)
      obj.setFloatProp(timerPID, getFloatObjProp(obj, timerName, 0))
    obj.sendNotify("activate")
    return ::RETCODE_NOTHING
  }

  function onDetach(obj)
  {
    obj.sendNotify("deactivate")
    return ::RETCODE_NOTHING
  }

  function onTimer(obj, dt)
  {
    local props = getProps(obj)
    props.timer <- obj.getFloatProp(timerPID, 0)
    props.timerBefore <- props.timer
    props.blink <- obj.getFinalProp("_blink")

    if (props.blink == "yes") {
      props.blink = "now"
      props.timer = (props.totalTime >= 0)? 0.0 : 1.0
    }

    props.timer = updateTimer(obj, dt, props)
    updateProps(obj, dt, props)

    if (props.blink == "now")
      if ((props.timer >= 1 && props.totalTime > 0) ||
          (props.timer <= 0 && props.totalTime < 0))
        props.blink = ""

    if (props.blink)
      obj["_blink"] = props.blink
    obj.setFloatProp(timerPID, props.timer);

    //border timer values (0 && 1) required for some css props update.
    if (props.timerBefore != props.timer)
      if (props.timer == 0.0 || props.timer == 1.0)
        obj[timerName] = props.timer.tointeger().tostring()
      else if (props.timerBefore == 0.0 || props.timerBefore == 1.0)
        obj[timerName] = props.timer.tostring()
  }

  function updateProps(obj, dt, p) {  //p - properties config
    local way = (p.totalTime >= 0)? 1.0 : -1.0
    local wayIdx = (p.totalTime >= 0)? 0 : 1

    local curSize = obj.getSize()
//    local curSize = [null, null] //!!Temporary for testing

    if (p.size0[0] != null) {
//      curSize[0] = getFloatObjProp(obj, "width")  //!!Temporary for testing
      local width = countProp(p.size0[0], p.size1[0], p.func[wayIdx], p.timer * way, p.scaleK[0])
      width = ::blendProp(curSize[0], width, p.blendTime, dt).tointeger()
      if (width != curSize[0])
        obj.width =  width.tostring()
//      dagor.debug(format("GP: WIDTH: cur = %f,  new = %f, blendTo = %s",
//                    curSize[0], width, obj.width))
    }
    if (p.size0[1] != null) {
//      curSize[1] = getFloatObjProp(obj, "height") //!!Temporary for testing
      local height = countProp(p.size0[1], p.size1[1], p.func[wayIdx], p.timer * way, p.scaleK[1])
      height = ::blendProp(curSize[1], height, p.blendTime, dt).tointeger()
      if (height != curSize[1])
        obj.height = height.tostring()
//      dagor.debug(format("GP: HEIGHT: cur = %f,  new = %f, blendTo = %s",
//                    curSize[1], height, obj.height))
    }
  }

  function countProp(propBase, propEnd, func, timer, scale = 1.0, obj = null) {
    return scale * (propBase + (propEnd - propBase) * basicFunction(func, timer))
  }

  function getProps(obj) {
    local props = {}
    //user params needed
    props.size0 <- [getFloatObjProp(obj, "width-base", null), getFloatObjProp(obj, "height-base", null)]
    props.size1 <- [getFloatObjProp(obj, "width-end"), getFloatObjProp(obj, "height-end")]
    props.totalTime <- getIntObjProp(obj, "size-time", 1000) / 1000.0
    props.cycled <- getBoolObjProp(obj, "size-cycled", false)

    //user params additional
    props.func <- [getObjProp(obj, "size-func")]
      props.func.append(getObjProp(obj, "size-backfunc", props.func[0]))

    props.blendTime <- getIntObjProp(obj, "blend-time", 100) / 1000.0
    props.scaleK <- getScaleK(obj, "size-scale")

    props.selfRemoveOnFinish <- getIntObjProp(obj, "selfRemoveOnFinish", 0)

    return props
  }

  function updateTimer(obj, dt, p) {  //p - properties config
    local timer = p.timer + ((p.totalTime == 0)? 0 : dt / p.totalTime)

    if (timer < 0) {
      timer = (p.cycled)? timer%1 + 1.0 : 0.0

      if (p.selfRemoveOnFinish < 0)
        selfRemove(obj)
    }
    if (timer > 1) {
      timer = (p.cycled)? timer%1 : 1.0
      if (p.selfRemoveOnFinish > 0)
        selfRemove(obj)
    }
    return timer
  }

  function selfRemove(obj) {
    local guiScene = obj.getScene()
    guiScene.performDelayed(this, (@(obj, guiScene) function() {
      if (obj && obj.isValid())
      {
        obj.sendNotify("end_edit")
        guiScene.destroyElement(obj)
      }
    })(obj, guiScene))
  }

  function getObjProp(obj, name, defaultRes = "") {
    local prop = obj.getFinalProp(name)
    return (prop)? prop : defaultRes
  }

  function sendNetAssert(err, obj, header)
  {
    ::script_net_assert_once("bhvBasic error",
                             "bhvBasic error (" + header
                             + ", obj = " + ::toString(obj)
                             + "):\n" + err)
  }

  function getIntObjProp(obj, name, defaultRes = 0)
  {
    local res = getObjProp(obj, name, defaultRes)
    if (!res)
      return res

    try
    {
      res = res.tointeger()
    }
    catch (err)
    {
      sendNetAssert(err, obj, "to integer prop '" + name + "' = '" + res + "' ")
      return defaultRes
    }
    return res
  }

  function getFloatObjProp(obj, name, defaultRes = 0.0)
  {
    local res = getObjProp(obj, name, defaultRes)
    if (!res)
      return res

    try
    {
      res = res.tofloat()
    }
    catch (err)
    {
      sendNetAssert(err, obj, "to float prop '" + name + "' = '" + res + "' ")
      return defaultRes
    }
    return res
  }

  function getBoolObjProp(obj, name, defaultRes = false) {
    local p = getObjProp(obj, name)
    if ((p == "yes")||(p == "true")||(p == "1"))
      return true
    if ((p == "no")||(p == "false")||(p == "0"))
      return false
    return defaultRes
  }

  function getScaleK(obj, name) {
    local scaleType = getObjProp(obj, name).tolower()

    if (scaleType == "")
      return [1.0, 1.0]

    if ((scaleType == "p")||(scaleType == "parent")) {
      local pSize = obj.getParent().getSize()
      return [0.01 * pSize[0], 0.01 * pSize[1]]
    }

    if (scaleType == "self") {
      local size = obj.getSize()
      return [0.01 * size[0], 0.01 * size[1]]
    }

    if (scaleType == "selfsize") {
      local size = obj.getSize()
      return [0.01 * size[1], 0.01 * size[0]]
    }

    local rootObj = obj.getScene().getRoot()
    local rootSize = rootObj.getSize()

    if ((scaleType == "sh")||(scaleType == "screenheight"))
      return [0.01 * rootSize[1], 0.01 * rootSize[1]]

    if ((scaleType == "s")||(scaleType == "screen"))
      return [0.01 * rootSize[0], 0.01 * rootSize[1]]

    return [1.0, 1.0]
  }

  eventMask = ::EV_TIMER
}

class gui_bhv_deprecated.basicPos extends gui_bhv_deprecated.basicSize
{
  timerName = "_pos-timer"
  timerPID = ::dagui_propid.add_name_id("_pos-timer")

  function updateProps(obj, dt, p) {  //p - properties config
    local parentObj = obj.getParent()
    local way = (p.totalTime >= 0)? 1.0 : -1.0
    local wayIdx = (p.totalTime >= 0)? 0 : 1

    local objSize = obj.getSize()
    local parentSize = parentObj.getSize()
    local curPos = obj.getPos()
    local parentPos = parentObj.getPos()
    curPos[0] = curPos[0] - parentPos[0]
    curPos[1] = curPos[1] - parentPos[1]

    local newPos = [
      countProp(p.pos0[0], p.pos1[0], p.func[wayIdx], p.timer * way, p.scaleK[0], obj),
      countProp(p.pos0[1], p.pos1[1], p.func[wayIdx], p.timer * way, p.scaleK[1], obj)
    ]

    if (p.hRel == "right")
      newPos[0] = parentSize[0] - objSize[0] - newPos[0]
    if (p.vRel == "bottom")
      newPos[1] = parentSize[1] - objSize[1] - newPos[1]

    obj.left = (::blendProp(curPos[0], newPos[0], p.blendTime, dt)).tointeger().tostring()
    obj.top = (::blendProp(curPos[1], newPos[1], p.blendTime, dt)).tointeger().tostring()
  }

  function getProps(obj) {
    local props = {}

    local hStart = getFloatObjProp(obj, "left-base", null)
    local hEnd   = getFloatObjProp(obj, "left-end", null)
    props.hRel <- "left"


    if (hStart == null && hEnd == null)
    {
      hStart = getFloatObjProp(obj, "right-base")
      hEnd   = getFloatObjProp(obj, "right-end")
      if (hStart != hEnd)
        props.hRel <- "right"
    }
    else
    {
      hStart = hStart ?? 0.0
      hEnd  = hEnd ?? 0.0
    }

    local vStart = getFloatObjProp(obj, "top-base", null)
    local vEnd   = getFloatObjProp(obj, "top-end", null)
    props.vRel <- "top"

    if (vStart == null && vEnd == null)
    {
      vStart = getFloatObjProp(obj, "bottom-base")
      vEnd   = getFloatObjProp(obj, "bottom-end")
      if (vStart != vEnd)
        props.vRel <- "bottom"
    }
    else
    {
      vStart = vStart ?? 0.0
      vEnd = vEnd ?? 0.0
    }

    props.pos0 <- [hStart, vStart]
    props.pos1 <- [hEnd, vEnd]
    props.totalTime <- getIntObjProp(obj, "pos-time", 1000) / 1000.0
    props.cycled <- getBoolObjProp(obj, "pos-cycled", false)

    //user params additional
    props.func <- [getObjProp(obj, "pos-func")]
      props.func.append(getObjProp(obj, "pos-backfunc", props.func[0]))
    props.blendTime <- getIntObjProp(obj, "blend-time", 100) / 1000.0
    props.scaleK <- getScaleK(obj, "pos-scale")

    props.selfRemoveOnFinish <- getIntObjProp(obj, "selfRemoveOnFinish", 0)

    return props
  }
}

class gui_bhv_deprecated.basicTransparency extends gui_bhv_deprecated.basicSize
{
  timerName = "_transp-timer"
  timerPID = ::dagui_propid.add_name_id("_transp-timer")

  function updateProps(obj, dt, p) {  //p - properties config
    local way = (p.totalTime >= 0)? 1.0 : -1.0
    local wayIdx = (p.totalTime >= 0)? 0 : 1

    local trNew = countProp(p.trBase, p.trEnd, p.func[wayIdx], p.timer * way)

    obj.set_prop_latent("color-factor", ::blendProp(p.trCur, trNew, p.blendTime, dt).tointeger().tostring())
    obj.updateRendElem();
  }

  function getProps(obj) {
    local props = {}
    //user params needed
    props.trBase <- getIntObjProp(obj, "transp-base", 255)
    props.trEnd <- getIntObjProp(obj, "transp-end", 255)
    props.trCur <- getIntObjProp(obj, "color-factor", props.trBase)

    props.totalTime <- getIntObjProp(obj, "transp-time", 1000) / 1000.0
    props.cycled <- getBoolObjProp(obj, "transp-cycled", false)

    //user params additional
    props.func <- [getObjProp(obj, "transp-func")]
    props.func.append(getObjProp(obj, "transp-backfunc", props.func[0]))
    props.blendTime <- getIntObjProp(obj, "blend-time", 100) / 1000.0

    props.selfRemoveOnFinish <- getIntObjProp(obj, "selfRemoveOnFinish", 0)

    return props
  }
}

//Works just like gui_bhv_deprecated.basicTransparency.
//But all objects with same periods will winkign synchronously.
class gui_bhv_deprecated.syncTransparency extends gui_bhv_deprecated.basicTransparency
{
  function updateTimer(obj, dt, p) {  //p - properties config
    local timer = ((::dagor.getCurTime().tofloat() / 1000) % p.totalTime) / p.totalTime

    if (timer < 0) {
      timer = (p.cycled)? timer%1 + 1.0 : 0.0

      if (p.selfRemoveOnFinish < 0)
        selfRemove(obj)
    }
    if (timer > 1) {
      timer = (p.cycled)? timer%1 : 1.0
      if (p.selfRemoveOnFinish > 0)
        selfRemove(obj)
    }
    return timer
  }
}

//Applied to all childs too. e careful using it.
class gui_bhv_deprecated.massTransparency extends gui_bhv_deprecated.basicTransparency
{
  last_transp_PID = ::dagui_propid.add_name_id("_last_transp")

  function onAttach(obj)
  {
    obj.sendNotify("activate")
    onTimer(obj, 0.0)
    return ::RETCODE_NOTHING
  }

  function updateProps(obj, dt, p)
  {
    local way = (p.totalTime >= 0)? 1.0 : -1.0
    local wayIdx = (p.totalTime >= 0)? 0 : 1

    local transpNew = countProp(p.trBase, p.trEnd, p.func[wayIdx], p.timer * way)
    transpNew = ::clamp(transpNew, 0, 255)
    local lastTransp = obj.getIntProp(last_transp_PID, -1)
    if (lastTransp >= 0) //do not blend on first update
      transpNew = ::blendProp(p.trCur, transpNew, p.blendTime, dt).tointeger()

    if (lastTransp == transpNew)
      return

    obj.setIntProp(last_transp_PID, transpNew)
    setTranspRecursive(obj, transpNew.tostring())
  }

  function setTranspRecursive(obj, value)
  {
    obj.set_prop_latent("color-factor", value)
    obj.updateRendElem()

    local totalObjs = obj.childrenCount()
    for(local i = 0; i < totalObjs; i++)
      setTranspRecursive(obj.getChild(i), value)
  }
}

::updateTransparencyRecursive <- function updateTransparencyRecursive(obj, transpNew)
{
  local last_transp_PID = ::dagui_propid.add_name_id("_last_transp")

  obj.setIntProp(last_transp_PID, transpNew.tointeger())
  obj.set_prop_latent("color-factor", transpNew)
  obj.updateRendElem()

  local totalObjs = obj.childrenCount()
  for(local i = 0; i < totalObjs; i++)
    ::updateTransparencyRecursive(obj.getChild(i), transpNew.tostring())
}

class gui_bhv_deprecated.basicRotation extends gui_bhv_deprecated.basicSize
{
  timerName = "_rot-timer"
  timerPID = ::dagui_propid.add_name_id("_rot-timer")

  function updateProps(obj, dt, p) {  //p - properties config
    local way = (p.totalTime >= 0)? 1.0 : -1.0
    local wayIdx = (p.totalTime >= 0)? 0 : 1

    local rotNew = countProp(p.rotBase, p.rotEnd, p.func[wayIdx], p.timer * way, 1.0, obj)

    obj.set_prop_latent("rotation", ::blendProp(p.rotCur, rotNew, p.blendTime, dt).tointeger().tostring())
    obj.markObjChanged()
  }

  function getProps(obj) {
    local props = {}
    //user params needed
    props.rotBase <- getIntObjProp(obj, "rot-base")
    props.rotEnd <- getIntObjProp(obj, "rot-end")
    props.rotCur <- getIntObjProp(obj, "rotation", props.rotBase)

    props.totalTime <- getIntObjProp(obj, "rot-time", 1000) / 1000.0
    props.cycled <- getBoolObjProp(obj, "rot-cycled", false)

    //user params additional
    props.func <- [getObjProp(obj, "rot-func")]
    props.func.append(getObjProp(obj, "rot-backfunc", props.func[0]))
    props.blendTime <- getIntObjProp(obj, "blend-time", 100) / 1000.0

    props.selfRemoveOnFinish <- getIntObjProp(obj, "selfRemoveOnFinish", 0)

    return props
  }
}

class gui_bhv_deprecated.basicFontSize extends gui_bhv_deprecated.basicSize
{
  timerName = "_size-timer"
  timerPID = ::dagui_propid.add_name_id("_size-timer")

  function onAttach(obj)
  {
    obj.sendNotify("activate")
    onTimer(obj, 0.0)
    return ::RETCODE_NOTHING
  }

  function updateProps(obj, dt, p) {  //p - properties config
    base.updateProps(obj, dt, p)

    local way = (p.totalTime >= 0)? 1.0 : -1.0
    local wayIdx = (p.totalTime >= 0)? 0 : 1

    local fontHtNew = countProp(p.fontHtBase, p.fontHtEnd, p.func[wayIdx], p.timer * way, p.scaleK[1])
    fontHtNew = (::blendProp(p.fontHtCur, fontHtNew, p.blendTime, dt)).tointeger()
    if (fontHtNew != p.fontHtCur)
      setFontHt(obj, fontHtNew)
  }

  function setFontHt(obj, fontHt)
  {
    obj["font-ht"] = fontHt
  }

  function getProps(obj) {
    local props = base.getProps(obj)

    props.fontHtBase <- getIntObjProp(obj, "font-ht-base", 10)
    props.fontHtEnd <- getIntObjProp(obj, "font-ht-end", props.fontHtBase)
    props.fontHtCur <- getIntObjProp(obj, "font-ht", -1)

    return props
  }
}

class gui_bhv_deprecated.basicFontSizeTextArea extends gui_bhv_deprecated.basicFontSize
{
  function setFontHt(obj, fontHt)
  {
    obj.set_prop_latent("font-ht", fontHt)
    obj.setValue(obj.getValueStr()) //no other way to correct recount text area on change font-ht
  }
}

class gui_bhv_deprecated.motionCursor extends gui_bhv_deprecated.basicSize
{
  function updateProps(obj, dt, p) {
    base.updateProps(obj, dt, p)
    local clicked = getBoolObjProp(obj, "clicked", false)

    if ((!clicked)&&(p.timer >= 1.0)) {
      obj["clicked"] = "yes"
      mouseClick(obj, true)
      return
    }
    if (clicked&&(p.timer <= 0.0)) {
      obj["clicked"] = "no"
      mouseClick(obj, false)
    }
  }

  function mouseClick(obj, state) {
    local curPos = obj.getPos()
    local parentPos = obj.getParent().getPos()
    curPos[0] = curPos[0] - parentPos[0]
    curPos[1] = curPos[1] - parentPos[1]
    if (state)
      obj.getScene().simulateMouseBtnDown(curPos[0], curPos[1], 0)
    else
      obj.getScene().simulateMouseBtnUp(curPos[0], curPos[1], 0)
  }
}

class gui_bhv_deprecated.motionCursorField extends gui_bhv_deprecated.basicSize
{
  function onMouseMove(obj, mx, my, bits) {
    if (obj.childrenCount() >= 1) {
      local cursor = obj.getChild(0)
      local clicked = getBoolObjProp(cursor, "clicked", false)
      if (!clicked) {
        local dev = [getFloatObjProp(cursor, "_last-x") - mx, getFloatObjProp(cursor, "_last-y") - my]
        local rootHeight = obj.getScene().getRoot().getSize()[1]
        if ((dev[0]*dev[0] + dev[1]*dev[1]) > (maxDeviationSq * rootHeight*rootHeight)) {
          cursor.setFloatProp(timerPID, 0)
          cursor["_last-x"] = mx.tointeger().tostring()
          cursor["_last-y"] = my.tointeger().tostring()
        }
      }
      cursor.left = mx.tointeger().tostring()
      cursor.top = my.tointeger().tostring()
    }

    return ::RETCODE_OBJ_CHANGED
  }

  maxDeviationSq = 0.0001  //sq of screen Height
  timerName = "_size-timer"
  timerPID = ::dagui_propid.add_name_id("_size-timer")
  eventMask = ::EV_MOUSE_MOVE
}

class gui_bhv_deprecated.shakePos extends gui_bhv_deprecated.basicPos {
  function countProp(propBase, propEnd, func, timer, scale, obj) {
    if ((timer==0)||(timer==1))
      return base.countProp(propBase, propEnd, func, timer, scale, obj)

    local deviation = getIntObjProp(obj, "deviation")
    local value = 0.01 * deviation * (2.0 * ::math.frnd() - 1.0)
    return scale * (propBase + (propEnd - propBase) * value)
  }
}

class gui_bhv_deprecated.shakeRotation extends gui_bhv_deprecated.basicRotation {
  function countProp(propBase, propEnd, func, timer, scale, obj) {
    if ((timer==0)||(timer==1))
      return base.countProp(propBase, propEnd, func, timer, scale, obj)

    local deviation = getIntObjProp(obj, "deviation")
    local value = 0.01 * deviation * (2.0 * ::math.frnd() - 1.0)
    return scale * (propBase + (propEnd - propBase) * value)
  }
}

class gui_bhv_deprecated.multiLayerImage extends gui_bhv_deprecated.basicSize
{
  eventMask = ::EV_TIMER
  last_mx_PID = ::dagui_propid.add_name_id("last_mx")
  rotationBasePID = ::dagui_propid.add_name_id("_rotation_base")
  /*
  function onAttach(obj)
  {
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    obj.setIntProp(last_mx_PID, cursorPos[0])
    updateChilds(obj, cursorPos[0], 0)
    return ::RETCODE_NOTHING
  }
  */

  function onTimer(obj, dt)
  {
    local mx = ::get_dagui_mouse_cursor_pos_RC()[0]
    local objMx = obj.getIntProp(last_mx_PID, 0)
    if (objMx == mx)
      return ::RETCODE_NOTHING

    local blendTime = getIntObjProp(obj, "blend-time", 100) / 1000.0
    objMx = ::blendProp(objMx, mx, blendTime, dt).tointeger()
    updateChilds(obj, objMx, 0)
    obj.setIntProp(last_mx_PID, objMx)
    return ::RETCODE_NOTHING
  }

  function updateChilds(obj, mx, my)
  {
    local rootSize = obj.getScene().getRoot().getSize()
    if (mx < 0) mx = 0
    if (mx > rootSize[0]) mx = rootSize[0]
    local deviation = mx.tofloat() - 0.5 * rootSize[0]

    local totalObjs = obj.childrenCount()
    for(local i = 0; i<totalObjs; i++)
    {
      local layerObj = obj.getChild(i)
      local sens = 0.01 * getFloatObjProp(layerObj, "layerSensitivity")
      if (sens != 0)
      {
        layerObj.set_prop_latent("left", (sens * deviation).tointeger().tostring())
        //layerObj.updateRendElem()
        //layerObj.recalcSize()
        layerObj.recalcPos()
      }

      local rotSens = 0.01 * getFloatObjProp(layerObj, "rotation-sensitivity")
      if (rotSens != 0)
      {
        local rotBase = layerObj.getFloatProp(rotationBasePID)
        if (rotBase == null)
        {
          rotBase = getFloatObjProp(layerObj, "rotation")
          layerObj.setFloatProp(rotationBasePID, rotBase)
        }
        local rotation = (rotBase + rotSens * deviation) //.tointeger()
        layerObj.set_prop_latent("rotation", ::format("%.2f", rotation))
        layerObj.markObjChanged()
      }
    }
  }
}
