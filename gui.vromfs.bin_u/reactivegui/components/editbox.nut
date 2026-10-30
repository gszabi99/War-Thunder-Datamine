




from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let font = fontsState.get("small")
let dpPx = cssConst("dp")
let padding = [px("5@sf/@pf"), px("8@sf/@pf")]

let focusLine = freeze({
  size = [flex(), 2 * dpPx]
  vplace = ALIGN_BOTTOM
  rendObj = ROBJ_SOLID
  color = cssColors.editboxFgColorFocus
})

function editBox(p, state = null, onChange = null, size = null) {
  let id = p?.id
  let text = state ?? Watched(p?.value ?? "")
  let elemSf = Watched(0)
  let editHint = p?.editHint ?? ""
  let { warning = null, tooltip = null, onCancel = null, onReturn = null } = p
  let onElemState = tooltip == null ? @(s) elemSf.set(s) : withHint(elemSf, id, tooltip)
  
  function refreshHint(_) {
    let sf = elemSf.get()
    onElemState(sf & ~S_HOVER)
    onElemState(sf)
  }
  let onAttach = tooltip == null ? null : @() warning?.subscribe(refreshHint)
  let onDetach = tooltip == null ? null : function() {
    warning?.unsubscribe(refreshHint)
    tooltipDetach(elemSf, id)()
  }
  let input = @() {
    watch = [text, elemSf, warning]
    key = id
    size = flex()
    rendObj = ROBJ_TEXT
    behavior = Behaviors.TextInput
    skipDirPadNav = p?.skipDirPadNav
    valign = ALIGN_CENTER
    font
    color = warning?.get() ? cssColors.warningTextColor
      : (elemSf.get() & (S_KB_FOCUS | S_HOVER)) != 0 ? cssColors.activeTextColor
      : cssColors.commonTextColor
    text = text.get()
    maxChars = p?.maxLen
    password = p?.password ? loc("password_mask_char", "*") : null
    inputType = p?.inputType
    title = p?.title
    onElemState
    onAttach
    onDetach
    onFocus = p?.onFocus
    onBlur = p?.onBlur
    function onChange(v) {
      if (state == null)
        text.set(v)
      onChange?(id, v)
    }
    onEscape = onCancel == null ? null : @() onCancel(id)
    onReturn = @() onReturn?(id)
    onImeFinish = @(_) onReturn?(id)
    imeOnFocus = p?.imeOnFocus ?? false
  }
  let hint = mkText(editHint, font, cssColors.editboxHintColor, { vplace = ALIGN_CENTER })
  let boxSize = size ?? [flex(), cssConst("buttonHeight")]
  return function() {
    let isFocused = (elemSf.get() & S_KB_FOCUS) != 0
    return {
      watch = [text, elemSf, warning]
      size = boxSize
      rendObj = ROBJ_BOX
      fillColor = isFocused ? cssColors.editboxColorFocus : cssColors.editboxColor
      borderColor = warning?.get() ? cssColors.warningTextColor
        : isFocused ? cssColors.editboxBorderColorFocus
        : cssColors.editboxBorderColor
      borderWidth = dpPx
      children = [
        !isFocused ? null : focusLine
        {
          size = flex()
          padding
          children = [
            text.get() != "" || isFocused ? null : hint
            input
          ]
        }
      ]
    }
  }
}

return editBox
