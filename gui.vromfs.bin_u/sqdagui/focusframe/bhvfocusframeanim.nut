local focusTarget = require("sqDagui/focusFrame/bhvFocusFrameTarget.nut")

//uses the first child to play anim.
//set self position and size according to target
//if animation function not set
//it set state _blink=yes to child object to start anim (so it should be tuned self as you need)

local registerFunc = null      //registerFunc(obj)
local unregisterFunc = null    //unregisterFunc(obj)
local animFunc = null         //animFunc(animObj, curTargetObjData, prevTargetObjData), where objData = { obj, size, pos }
local hideTgtImageTimeMsec = 0

local minDiffForAnimPx = 10

const SWITCH_OFF_TIME = 10000000

local PROPID_TIMER_TIMENOW = ::dagui_propid.add_name_id("timer-timenow")
::dagui_propid.add_name_id("focusImageSource")

local bhvFocusFrameAnim = class
{
  eventMask = ::EV_TIMER
  imageParamsList = ["image", "color", "position", "repeat", "svg-size", "rotation"]

  function onAttach(obj)
  {
    setDelay(obj, SWITCH_OFF_TIME)
    if (registerFunc)
      registerFunc(obj)
    return ::RETCODE_NOTHING
  }

  function onDetach(obj)
  {
    if (unregisterFunc)
      unregisterFunc(obj)
    return ::RETCODE_NOTHING
  }

  function play(obj, targetObj)
  {
    if (obj.childrenCount() < 1)
      return

    local animObj = obj.getChild(0)
    if (!::check_obj(animObj) || !::check_obj(targetObj))
      return

    local prevData = obj.getUserData()
    local curData = gatherObjData(targetObj)
    if (!needAnim(curData, prevData))
    {
      if (::check_obj(curData?.obj))
        focusTarget.unhideImage(curData.obj)
      return
    }

    obj.setUserData(curData)

    if (hideTgtImageTimeMsec > 0)
    {
      //restore target image to collect data
      focusTarget.unhideImage(targetObj)
      animObj.getScene().applyPendingChanges(false)
    }

    //set image visual from target
    local focusImageSource = targetObj.getFinalProp("focusImageSource")
    local imagePrefixList = {
      ["background-"] = focusImageSource != "foreground",
      ["foreground-"] = focusImageSource != "background"
    }

    animObj["re-type"] = targetObj.getFinalProp("re-type") ?? "root"
    foreach(prefix, isUsed in imagePrefixList)
      foreach(key in imageParamsList)
      {
        local fullKey = prefix + key
        animObj[fullKey] = isUsed ? targetObj.getFinalProp(fullKey) ?? "" : ""
      }

    if (hideTgtImageTimeMsec > 0)
    {
      focusTarget.hideImage(targetObj)
      setDelay(obj, hideTgtImageTimeMsec)
    }

    //set position and size
    local pos = targetObj.getPosRC()
    local size = targetObj.getSize()
    obj.position = "root"
    obj.left = curData.pos[0]
    obj.top = curData.pos[1]
    obj.width = curData.size[0]
    obj.height = curData.size[1]

    //start anim
    if (animFunc)
      animFunc(animObj, curData, prevData)
    animObj._blink = "yes"
  }

  function gatherObjData(targetObj)
  {
    return {
      obj = targetObj
      size = targetObj.getSize()
      pos = targetObj.getPosRC()
    }
  }

  function restoreTargetImage(obj)
  {
    local curData = obj.getUserData()
    if (::check_obj(curData?.obj))
      focusTarget.unhideImage(curData.obj)
  }

  function needAnim(curTgt, prevTgt)
  {
    if (!prevTgt)
      return true

    foreach(propName in ["size", "pos"])
      foreach(axis, value in curTgt[propName])
        if (::abs(prevTgt[propName][axis] - value) > minDiffForAnimPx)
          return true
    return false
  }

  function setDelay(obj, timeMsec)
  {
    obj.setIntProp(PROPID_TIMER_TIMENOW, 0)
    obj.timer_interval_msec = timeMsec.tostring()
  }

  function onTimer(obj, dt)
  {
    setDelay(obj, SWITCH_OFF_TIME)
    restoreTargetImage(obj)
  }
}

::replace_script_gui_behaviour("focusFrameAnim", bhvFocusFrameAnim)

return {
   play = @(animObj, targetParams) bhvFocusFrameAnim.play(animObj, targetParams)

   setRegisterFunctions = function(registerFunction, unregisterFunction)
   {
     registerFunc = registerFunction
     unregisterFunc = unregisterFunction
   }

   setAnimFunction = @(animFunction)  animFunc = animFunction
   setHideTgtImageTimeMsec = function(timeMsec)
   {
     hideTgtImageTimeMsec = timeMsec
     focusTarget.setShouldHideImage(hideTgtImageTimeMsec > 0)
   }
}