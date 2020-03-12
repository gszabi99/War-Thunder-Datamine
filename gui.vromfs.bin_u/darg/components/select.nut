local defStyle = require("select.style.nut")

local mkSelItem = @(state, onClickCtor=null, isCurrent=null, textCtor=null, elemCtor = null, style=null) elemCtor==null ? function selItem(p, idx, list){
  local stateFlags = ::Watched(0)
  isCurrent = isCurrent ?? @(p, idx) p==state.value
  local onClick = onClickCtor!=null ? onClickCtor(p, idx) : @() state(p)
  local text = textCtor != null ? textCtor(p, idx, stateFlags) : p
  local {textCommonColor, textActiveColor, textHoverColor, borderColor, borderRadius, borderWidth,
        bkgActiveColor, bkgHoverColor, bkgNormalColor, padding} = (style ?? defStyle.elemStyle)
  return function(){
    local selected = isCurrent(p, idx)
    return {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_BOX
      onElemState = @(sf) stateFlags(sf)
      behavior = Behaviors.Button
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      padding = padding
      stopHover = true
      watch = [stateFlags, state]
      children = {
        rendObj = ROBJ_DTEXT, text=text,
        color = (stateFlags.value & S_HOVER)
          ? textHoverColor
          : selected
            ? textActiveColor
            : textCommonColor,
        padding = borderRadius, font=Fonts.medium_text
      }
      onClick = onClick
      borderColor = borderColor
      borderWidth = borderWidth
      borderRadius = list.len()==1 || (borderRadius ?? 0)==0
        ? borderRadius
        : idx==0
          ? [borderRadius,0,0, borderRadius]
          : idx==list.len()-1
            ? [0,borderRadius,borderRadius, 0]
            : 0
      fillColor = stateFlags.value & S_HOVER
        ? bkgActiveColor
        : selected
          ? bkgHoverColor
          : bkgNormalColor
    }
  }
}  : elemCtor

local select = ::kwarg(function selectImpl(state, options, onClickCtor=null, isCurrent=null, textCtor=null, elem_style=null, root_style=null){
  local selItem = mkSelItem(state, onClickCtor, isCurrent, textCtor, elem_style)
  return function(){
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = options.map(selItem)
    }.__update(root_style ?? defStyle.rootStyle)
  }
})

return select