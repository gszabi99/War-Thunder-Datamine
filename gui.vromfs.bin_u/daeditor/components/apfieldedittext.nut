from "%darg/ui_imports.nut" import *
from "style.nut" import colors, gridHeight, gridMargin

let { compValToString, isValueTextValid, convertTextToVal } = require("attrUtil.nut")




function fieldEditText(desc) {
  let { eid, key, value, setValue, readOnly, sqType } = desc

  let curText = Watched("")
  let isFocus = Watched(false)
  let group = ElemGroup()
  let stateFlags = Watched(0)
  
  
  let text = Computed(@() isFocus.get() ? curText.get() : compValToString(value.get()))
  let isValid = Computed(@() isValueTextValid(sqType, text.get()))
  let okTrigger = $"ok:{eid}:{key}"
  let failTrigger = $"fail:{eid}:{key}"

  let resetText = @() curText.set(compValToString(value.get()))

  function frame() {
    let frameColor = (stateFlags.get() & S_KB_FOCUS) ? colors.FrameActive : colors.FrameDefault
    return {
      rendObj = ROBJ_FRAME group=group size = [flex(), gridHeight] color = frameColor watch = stateFlags
      onElemState = @(sf) stateFlags.set(sf)
    }
  }

  function doApply() {
    if (readOnly)
      return
    let cur = value.get()
    let typed = curText.get()
    if (compValToString(cur) == typed)
      return
    
    if (isValueTextValid(sqType, typed)) {
      local val = null
      try {
        val = convertTextToVal(sqType, typed)
      } catch(e) {
        val = null
      }
      if (val != null && setValue(val)) {
        anim_start(okTrigger)
        return
      }
    }
    anim_start(failTrigger)
  }

  function textInput() {
    return {
      rendObj = ROBJ_TEXT
      size = FLEX_H
      margin = gridMargin

      color = !isValid.get()
                ? colors.TextError
                : readOnly
                  ? colors.TextReadOnly
                  : colors.TextDefault

      text = text.get()
      behavior = readOnly ? null : Behaviors.TextInput
      group = group
      watch = [text, isValid]
      onChange = @(t) curText.set(t)
      onReturn = function() {
        isFocus.set(false)
        doApply()
        set_kb_focus(null)
      }
      onEscape = function() {
        isFocus.set(false)
        resetText()
        set_kb_focus(null)
      }
      onFocus = function() {
        isFocus.set(true)
        resetText()
      }
      onBlur = function() {
        isFocus.set(false)
        doApply()
      }
    }
  }

  return {
    key = $"{eid}:{key}"
    size = FLEX_H
    rendObj = ROBJ_SOLID
    color = colors.ControlBg

    animations = [
      { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=okTrigger }
      { prop=AnimProp.color, from=colors.HighlightFailure, duration=0.5, trigger=failTrigger }
    ]

    children = {
      size = FLEX_H
      children = [
        textInput
        frame
      ]
    }
  }
}

return fieldEditText
