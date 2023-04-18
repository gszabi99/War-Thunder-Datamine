#explicit-this
#no-root-fallback

local onSetTarget = null    //onSetTarget(oDaguiObject)
local onUnsetTarget = null  //onUnsetTarget(DaguiObject)
local shouldHideImage = false

let function hideImage(obj) {
  let focusImageSource = obj.getFinalProp("focusImageSource")
  if (focusImageSource == null)
    return

  let style = []
  if (focusImageSource != "foreground")
    style.append("background-color:#00000000;")
  if (focusImageSource != "background")
    style.append("foreground-color:#00000000;")
  obj.style = "".join(style)
}


let function unhideImage(obj) {
  obj.style = "background-color:; foreground-color:;"
}


let class bhvFocusFrameTarget {
  function onAttach(obj) {
    if (onSetTarget) {
      //instant hide image, because there is a single frame before animaton start with correct object sizes
      if (shouldHideImage)
        hideImage(obj)
      onSetTarget(obj)
    }
    return RETCODE_NOTHING
  }

  function onDetach(obj) {
    if (onUnsetTarget)
      onUnsetTarget(obj)
    if (shouldHideImage)
      unhideImage(obj)
    return RETCODE_NOTHING
  }
}

let function setCallbacks(onSetTargetCb, onUnsetTargetCb) {
  onSetTarget = onSetTargetCb
  onUnsetTarget = onUnsetTargetCb
}


::replace_script_gui_behaviour("focusFrameTarget", bhvFocusFrameTarget)

return {
  setCallbacks
  setShouldHideImage = @(shouldHide) shouldHideImage = shouldHide
  hideImage
  unhideImage
}