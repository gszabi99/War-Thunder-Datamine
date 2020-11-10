local defStyle = {}
local defTextStyle = {}
local defBoxStyle = {
  padding = hdpx(3)
  borderWidth = hdpx(1)
  borderRadius = hdpx(2)
  color = Color(150,150,150)
  hoverColor = Color(250,250,250)
}

local function defMkText(text, state=null, stateFlags=null, style = null){
  return @(){
    watch = [state, stateFlags]
    rendObj = ROBJ_DTEXT
    text = text
  }.__update(style ?? {})
}

local function defMkBox(size, state=null, stateFlags=null, boxStyle=null){
  local color = boxStyle?.color ?? defBoxStyle.color
  local hoverColor = boxStyle?.hoverColor ?? defBoxStyle.hoverColor
  local borderRadius = boxStyle?.borderRadius ?? defBoxStyle.borderRadius
  return function() {
    local sf = stateFlags?.value ?? 0
    return {
      rendObj = ROBJ_BOX
      size = size
      watch = stateFlags
      borderColor = sf ? hoverColor : color
      children = @(){
        watch = state
        rendObj = ROBJ_BOX
        size = flex()
        borderColor = 0
        fillColor = !state?.value
          ? sf & S_HOVER ? color : 0
          : sf & S_HOVER ? hoverColor : color
        borderRadius = borderRadius
      }
    }.__update(boxStyle ?? {})
  }
}

local function checkboxCtor(state, text = null, style = defStyle, textCtor = defMkText, textStyle = defTextStyle, boxCtor = defMkBox, boxStyle = defBoxStyle){
  local stateFlags = Watched(0)
  local h =::calc_comp_size(textCtor("h"))
  local hWidth = h[0]
  local hHeight = h[1]
  local box = boxCtor([hHeight, hHeight], state, stateFlags, boxStyle)
  local label = textCtor(text, state, stateFlags, textStyle )
  return function checkbox(){
    return {
      behavior = Behaviors.Button
      onClick = @() state(!state.value)
      onElemState = @(sf) stateFlags(sf)
      flow = FLOW_HORIZONTAL
      gap = hWidth
      children = [box, label]
    }.__update(style)
  }
}

return {
  checkbox = ::kwarg(checkboxCtor)
  defStyle
  defTextStyle
  defBoxStyle
}