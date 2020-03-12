local focusTarget = require("sqDagui/focusFrame/bhvFocusFrameTarget.nut")
local focusAnim = require("sqDagui/focusFrame/bhvFocusFrameAnim.nut")

local animObjList = []

local focusFrame = {
  isEnabled = false

  setAnimFunction = @(func) focusAnim.setAnimFunction(func)
  setHideTgtImageTimeMsec = @(timeMsec) focusAnim.setHideTgtImageTimeMsec(timeMsec)

  enable = function(shouldEnable)
  {
    isEnabled = shouldEnable
    focusTarget.setCallbacks(
      shouldEnable ? onSetTarget.bindenv(this) : null,
      null
    )
  }

  addAnimObj = @(obj) animObjList.append(obj)

  removeAnimObj = function(obj)
  {
    validateObjList()
    foreach(idx, o in animObjList)
      if (o.isEqual(obj))
      {
        animObjList.remove(idx)
        break
      }
  }

  onSetTarget = function(tgtObj)
  {
    local curObj = null
    local curModalCounter = 0
    foreach(obj in animObjList)
    {
      if (!::check_obj(obj) || !obj.isVisible() || !obj.isEnabled())
        continue

      local modalCounter = obj.getModalCounter()
      if (curObj && modalCounter > curModalCounter) //use last obj if same counter
        continue

      curObj = obj
      curModalCounter = modalCounter
    }

    if (curObj)
      playAnimDelayed(curObj, tgtObj)
  }

  //!!FIX ME: perform delayed sometimes called instently without real delay. this function try to catch this
  function playAnimDelayed(curObj, tgtObj, shouldCheckDelayedBug = true)
  {
    curObj.getScene().performDelayed(this, function()
    {
      if (!::check_obj(curObj) || !::check_obj(tgtObj))
        return

      if (shouldCheckDelayedBug && tgtObj.getSize()[0] == -1)
        playAnimDelayed(curObj, tgtObj, false)
      else
        focusAnim.play(curObj, tgtObj)
    })
  }

  validateObjList = function()
  {
    for(local i = animObjList.len() - 1; i >= 0; i--)
      if (!::check_obj(animObjList[i]))
         animObjList.remove(i)
  }
}

focusAnim.setRegisterFunctions(@(obj) focusFrame.addAnimObj(obj), @(obj) focusFrame.removeAnimObj(obj))
focusFrame.enable(true)

return focusFrame