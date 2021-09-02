local Color = ::Color
local defHeight = ::calc_comp_size({rendObj = ROBJ_DTEXT text="A"})[1]


local function listItem(text, action, is_current, params={}) {
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)
  local xmbNode = ::XmbNode()

  return function() {
    local textColor
    if (is_current)
      textColor = Color(255,255,235)
    else
      textColor = (stateFlags.value & S_HOVER) ? Color(255,255,255) : Color(120,150,160)

    return {
      behavior = [Behaviors.Button, Behaviors.Marquee]
      size = [flex(), SIZE_TO_CONTENT]
      xmbNode
      group
      watch = stateFlags

      onClick = action
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_DTEXT
        margin = sh(0.5)
        text
        color = textColor
        group
      }
    }
  }
}


local function closeButton(action) {
  return {
    size = flex()
    behavior = Behaviors.Button
    onClick = action
    rendObj = ROBJ_FRAME
    borderWidth = ::hdpx(1)
    color = Color(250,200,50,200)
  }
}


local function boxCtor(params=null) {
  local color = params?.disabled ? Color(160,160,160,255) : Color(255,255,255,255)

  local labelText = {
    group = params.group
    rendObj = ROBJ_DTEXT
    behavior = Behaviors.Marquee
    margin = sh(0.5)
    text = params.text
    key = params.text
    color = color
    size = [flex(), SIZE_TO_CONTENT]
  }


  local function popupArrow() {
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [defHeight/3,defHeight/3]
      margin = sh(0.5)
      color = color
      commands = [
        [VECTOR_WIDTH, ::hdpx(1)],
        [VECTOR_POLY, 0,0, 50,100, 100,0],
      ]
    }
  }

  return {
    size = flex()
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = [
      labelText
      popupArrow
    ]
  }
}


local function onOpenDropDown(itemXmbNode) {
  ::gui_scene.setXmbFocus(null)
}


return {
  popupBgColor = Color(20, 30, 36)
  popupBdColor = Color(90,90,90)
  popupBorderWidth = hdpx(1)
  itemGap = {rendObj=ROBJ_FRAME size=[flex(),hdpx(1)] color=Color(90,90,90)}

  rootBaseStyle = {}
  boxCtor
  listItem
  closeButton
  onOpenDropDown
}
