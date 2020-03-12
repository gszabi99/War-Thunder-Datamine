local onSetTarget = null    //onSetTarget(oDaguiObject)
local onUnsetTarget = null  //onUnsetTarget(DaguiObject)
local shouldHideImage = false

local bhvFocusFrameTarget = class
{
  function onAttach(obj)
  {
    if (onSetTarget)
    {
      //instant hide image, because there is a single frame before animaton start with correct object sizes
      if (shouldHideImage)
        hideImage(obj)
      onSetTarget(obj)
    }
    return ::RETCODE_NOTHING
  }

  function onDetach(obj)
  {
    if (onUnsetTarget)
      onUnsetTarget(obj)
    if (shouldHideImage)
      unhideImage(obj)
    return ::RETCODE_NOTHING
  }

  static function hideImage(obj)
  {
    local focusImageSource = obj.getFinalProp("focusImageSource")
    local style = ""
    if (focusImageSource != "foreground")
      style += "background-color:#00000000;"
    if (focusImageSource != "background")
      style += "foreground-color:#00000000;"
    obj.style = style
  }

  static function unhideImage(obj)
  {
    obj.style = "background-color:; foreground-color:;"
  }
}

::replace_script_gui_behaviour("focusFrameTarget", bhvFocusFrameTarget)

return {
  setCallbacks = function(onSetTargetCb, onUnsetTargetCb)
  {
    onSetTarget = onSetTargetCb
    onUnsetTarget = onUnsetTargetCb
  }

  setShouldHideImage = @(shouldHide) shouldHideImage = shouldHide
  hideImage = bhvFocusFrameTarget.hideImage
  unhideImage = bhvFocusFrameTarget.unhideImage
}