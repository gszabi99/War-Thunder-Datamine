local {colors, gridHeight, gridMargin} = require("style.nut")
local {compValToString, isValueTextValid, convertTextToVal, setValToObj, getValFromObj} = require("attrUtil.nut")
local entity_editor = require("entity_editor")

local getCompVal = @(eid, obj, path, comp_name) path!=null ? getValFromObj(obj, path) : ::ecs.get_comp_val(eid, comp_name)
local function fieldEditText_(params={}) {
  local {eid, obj, comp_name, compVal, setVal, path} = params

  local curText = Watched(compValToString(compVal))
  local group = ::ElemGroup()
  local compType = typeof compVal
  local stateFlags = Watched(0)
  local function onChange(text){
    params?.onChange?()
    curText.update(text)
  }

  local function frame() {
    local frameColor = (stateFlags.value & S_KB_FOCUS) ? colors.FrameActive : colors.FrameDefault
    return {
      rendObj = ROBJ_FRAME group=group size = [flex(), gridHeight] color = frameColor watch = stateFlags
      onElemState = @(sf) stateFlags.update(sf)
    }
  }

  local function textInput() {
    local isValid = isValueTextValid(compType, curText.value)

    local function updateTextFromEcs() {
      local val = getCompVal(eid, obj, path, comp_name)
      local compTextVal = compValToString(val)
      curText.update(compTextVal)
    }
    local function doApply() {
      if (isValid) {
        local val = null
        try {
          val = convertTextToVal(compType, curText.value)
        } catch(e) {
          val = null
        }
        if (val != null && setVal(val)) {
          ::anim_start($"{comp_name}{"".join(path??[])}")
          ::gui_scene.clearTimer(updateTextFromEcs)
          ::gui_scene.setTimeout(0.1, updateTextFromEcs) //do this in case when some es changes components
          return
        }
      }
      ::anim_start($"!{comp_name}{"".join(path??[])}")
    }

    return {
      rendObj = ROBJ_DTEXT
      size = [flex(), SIZE_TO_CONTENT]
      margin = gridMargin

      color = isValid ? colors.TextDefault : colors.TextError

      text = curText.value
      behavior = Behaviors.TextInput
      group = group
      watch = curText

      onChange = onChange

      function onReturn() {
        doApply()
        ::set_kb_focus(null)
      }

      function onEscape() {
        updateTextFromEcs()
        ::set_kb_focus(null)
      }

      onFocus = updateTextFromEcs
      onBlur = @() doApply()
    }
  }


  return function() {
    return {
      key = $"{eid}:{comp_name}{"".join(path??[])}"
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_SOLID
      color = colors.ControlBg

      animations = [
        { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=$"{comp_name}{"".join(path??[])}" }
        { prop=AnimProp.color, from=colors.HighlightFailure, duration=0.5, trigger=$"!{comp_name}{"".join(path??[])}" }
      ]

      children = {
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          textInput
          frame
        ]
      }
    }
  }
}

local function fieldEditText(params={}){
  local {eid, obj, comp_name, path=null, onChange=null} = params
  local function setVal(val) {
    if (path != null) {
      setValToObj(obj, path, val)
      return true
    }
    else {
      local ok = false
      try {
        local onChangeLocal = onChange ?? (@() ::ecs.set_comp_val(eid, comp_name, val) ?? true)
        ok = onChangeLocal()
      }
      catch (e) {
        ok = false
      }
      if (ok)
        entity_editor.save_component(eid, comp_name)
      return ok
    }
  }

  params = params.__merge({
    compVal = getCompVal(eid, obj, path, comp_name)
    setVal = setVal
  })
  return fieldEditText_(params)
}

return fieldEditText
