local Callback = require("sqStdLibs/helpers/callback.nut").Callback
::g_script_reloader.loadOnce("sqDagui/daguiUtil.nut")

::Timer <- class
{
  onTimeOut   = null
  cycled      = false
  isDelayed   = false
  guiScene    = null
  timerGuiObj = null

  static timeNowPID = ::dagui_propid.add_name_id("timer-timenow")

  constructor(parentObj, _delay, _onTimeOut, handler = null, _cycled = false, _isDelayed = false)
  {
    if (!_onTimeOut)
      return ::dagor.assertf(false, "Error: no onTimeOut in Timer.")

    onTimeOut = handler ? Callback(_onTimeOut, handler) : _onTimeOut
    cycled    = _cycled
    isDelayed = _isDelayed

    guiScene = parentObj.getScene()
    timerGuiObj = guiScene.createElement(parentObj, "timer", this)
    timerGuiObj.timer_handler_func = "onUpdate"
    timerGuiObj.timer_interval_msec = (_delay * 1000.0).tointeger().tostring()
    timerGuiObj.setUserData(this)
  }

  function onUpdate(obj, dt)
  {
    performAction()

    if (!cycled)
      destroy()
  }

  function performAction()
  {
    if (!isDelayed)
      onTimeOut()
    else
      guiScene.performDelayed(this, (@(onTimeOut) function() { onTimeOut() })(onTimeOut))
  }

  function setDelay(newDelay)
  {
    if (::check_obj(timerGuiObj))
    {
      timerGuiObj.timer_interval_msec = (newDelay * 1000.0).tointeger().tostring()
      timerGuiObj.setIntProp(timeNowPID, 0)
    }
  }

  function setCb(_onTimeOut)
  {
    onTimeOut = _onTimeOut
  }

  function destroy()
  {
    if (::check_obj(timerGuiObj))
    {
      timerGuiObj.setUserData(null)
      guiScene.destroyElement(timerGuiObj)
    }
  }

  function isValid()
  {
    return ::check_obj(timerGuiObj)
  }
}
