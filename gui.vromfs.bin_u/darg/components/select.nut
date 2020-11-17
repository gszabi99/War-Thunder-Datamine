local defStyle = require("select.style.nut")

local mkSelItem = @(state, onClickCtor=null, isCurrent=null, textCtor=null, elemCtor = null, style=null) elemCtor==null ? function selItem(p, idx, list){
  local stateFlags = ::Watched(0)
  isCurrent = isCurrent ?? @(p, idx) p==state.value
  local onClick = onClickCtor!=null ? onClickCtor(p, idx) : @() state(p)
  local text = textCtor != null ? textCtor(p, idx, stateFlags) : p
  local {textCommonColor, textActiveColor, textHoverColor, borderColor, borderRadius, borderWidth,
        bkgActiveColor, bkgHoverColor, bkgNormalColor, padding} = defStyle.elemStyle.__merge(style ?? {})
  return function(){
    local selected = isCurrent(p, idx)
    local nBw = borderWidth
    if (list.len() > 2) {
      if (idx != list.len()-1 && idx != 0)
        nBw = [borderWidth,0,borderWidth,borderWidth]
      if (idx == 1)
        nBw = [borderWidth,0,borderWidth,0]
    }
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
      borderWidth = nBw
      borderRadius = list.len()==1 || (borderRadius ?? 0)==0
        ? borderRadius
        : idx==0
          ? [borderRadius, 0, 0, borderRadius]
          : idx==list.len()-1
            ? [0,borderRadius, borderRadius, 0]
            : 0
      fillColor = stateFlags.value & S_HOVER
        ? bkgActiveColor
        : selected
          ? bkgHoverColor
          : bkgNormalColor
    }
  }
}  : elemCtor

local select = ::kwarg(function selectImpl(state, options, onClickCtor=null, isCurrent=null, textCtor=null, elemCtor=null, elem_style=null, root_style=null, flow = FLOW_HORIZONTAL){
  local selItem = mkSelItem(state, onClickCtor, isCurrent, textCtor, elemCtor, elem_style)
  return function(){
    return {
      size = SIZE_TO_CONTENT
      flow = flow
      children = options.map(selItem)
    }.__update(root_style ?? defStyle.rootStyle)
  }
})

return select