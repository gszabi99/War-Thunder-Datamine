let Callback = require("%sqStdLibs/helpers/callback.nut").Callback
::g_script_reloader.loadOnce("%sqDagui/daguiUtil.nut")

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

    this.onTimeOut = handler ? Callback(_onTimeOut, handler) : _onTimeOut
    this.cycled    = _cycled
    this.isDelayed = _isDelayed

    this.guiScene = parentObj.getScene()
    this.timerGuiObj = this.guiScene.createElement(parentObj, "timer", this)
    this.timerGuiObj.timer_handler_func = "onUpdate"
    this.timerGuiObj.timer_interval_msec = (_delay * 1000.0).tointeger().tostring()
    this.timerGuiObj.setUserData(this)
  }

  function onUpdate(obj, dt)
  {
    this.performAction()

    if (!this.cycled)
      this.destroy()
  }

  function performAction()
  {
    if (!this.isDelayed)
      this.onTimeOut()
    else
      this.guiScene.performDelayed(this, (@(onTimeOut) function() { onTimeOut() })(this.onTimeOut))
  }

  function setDelay(newDelay)
  {
    if (::check_obj(this.timerGuiObj))
    {
      this.timerGuiObj.timer_interval_msec = (newDelay * 1000.0).tointeger().tostring()
      this.timerGuiObj.setIntProp(this.timeNowPID, 0)
    }
  }

  function setCb(_onTimeOut)
  {
    this.onTimeOut = _onTimeOut
  }

  function destroy()
  {
    if (::check_obj(this.timerGuiObj))
    {
      this.timerGuiObj.setUserData(null)
      this.guiScene.destroyElement(this.timerGuiObj)
    }
  }

  function isValid()
  {
    return ::check_obj(this.timerGuiObj)
  }
}
