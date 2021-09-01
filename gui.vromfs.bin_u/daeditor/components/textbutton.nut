from "%darg/ui_imports.nut" import *

local style = {
  text = {
    normal = {
      color = Color(200,200,200)
      transform = {}
    }
    hover = {
      color = Color(0,0,0)
    }
    active = {
      color = Color(0,0,0)
    }
  }
  box = {
    normal = {
      margin = [hdpx(1),hdpx(10)]
      borderColor = Color(200,200,200)
      borderRadius = hdpx(4)
      fillColor = Color(10,10,10)
      padding = [hdpx(4), hdpx(10)]
      transform = {}
    }
    active = {
      fillColor = Color(200,200,200)
      pos = [0, hdpx(1)]
    }
    hover = {
      fillColor = Color(255,255,255)
      borderColor = Color(155,155,255)
    }
  }
}

local function textButton(text, handler, params = {}){
  local stateFlags = Watched(0)
  local disabled = params?.disabled
  local textStyle = style.text
  local boxStyle = style.box
  local textNormal = textStyle.normal
  local boxNormal = boxStyle.normal
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
    }.__update(boxNormal, boxS, {
      watch = [stateFlags, disabled]
      onElemState = @(sf) stateFlags(sf)
      behavior = Behaviors.Button
      hotkeys = params?.hotkeys
      onClick = handler
      children = {rendObj = ROBJ_DTEXT text}.__update(textNormal, textS)
    })
  }

}

return textButton
