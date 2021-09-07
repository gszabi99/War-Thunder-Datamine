from "%darg/ui_imports.nut" import *

local defButtonStyle = {
  text = {
    normal = {
      color = Color(200,200,200)
    }
    hover = {
      color = Color(220,240,255)
    }
    active = {
      color = Color(255,255,255)
    }
  }
  box = {
    normal = {
      borderWidth = hdpx(1)
      borderColor = Color(60,60,60)
      fillColor = Color(40,40,40)
      padding = [hdpx(4), hdpx(7)]
      margin = hdpx(2)
      borderRadius = hdpx(2)
    }
  }
}

local function textButton(text, handler= @() null, params = {}, style = defButtonStyle){
  local stateFlags = Watched(0)
  local disabled = params?.disabled
  local textStyle = style?.text ?? defButtonStyle.text
  local boxStyle = style?.box ?? defButtonStyle.box
  local textNormal = textStyle?.normal ?? defButtonStyle.text.normal
  local boxNormal = boxStyle?.normal ?? defButtonStyle.box.normal
  return function(){
    local s = stateFlags.value
    local state = "normal"
    if (disabled?.value)
      state = "disabled"
    else if (s & S_ACTIVE)
      state = "active"
    else if (s & S_HOVER)
      state = "hover"

    local textS = textStyle?[state] ?? {}
    local boxS = boxStyle?[state] ?? {}
    return {
      rendObj = ROBJ_BOX
      children = {rendObj = ROBJ_DTEXT text}.__update(textNormal, textS)
    }.__update(boxNormal, boxS, {
      watch = [stateFlags, disabled]
      onElemState = @(sf) stateFlags(sf)
      behavior = Behaviors.Button
      hotkeys = params?.hotkeys
      onClick = handler
    })
  }

}
return freeze({
  textButton
  defButtonStyle
})