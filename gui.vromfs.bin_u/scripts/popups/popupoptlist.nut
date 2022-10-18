from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

const SELECTOR_OBJ = "selector_obj"
const ACTION_BTN = "action_btn"

let deafaulEmptyOpt = {
  text = loc("options/aaaNone")
  tooltip = null
  isUnstable = false
  image = null
  enable = true
  name = null
}

local popupOptList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupOptList"

  stateList            = null
  tmpStates            = null
  resetId              = null
  isForcedSelect       = false

  //init params
  actionText           = null
  optionsList          = null
  onActionFn           = null

  function getSceneTplView() {
    stateList = {}
    local rows = []
    foreach (idx, inst in optionsList) {
      let { optType, title, exceptions = [], isEmptyDefault = false } = inst
      let objId = $"cb_{idx}"
      let option = ::get_option(optType)
      let items = (isEmptyDefault ? [deafaulEmptyOpt].extend(option.items) : option.items)
        .filter(@(v) !exceptions.contains(v.text))
      let valBySelector = inst.name
        ? items.findindex(@(v) v.name == inst.name)
        : isEmptyDefault ? 0 : option.value
      rows.append({
        title
        optType
        isEmptyDefault
        options = ::create_option_combobox(objId, items, valBySelector, null, false)
      })
      inst.items <- items
      stateList[objId] <- {
        optType
        name = inst.name
        val = option.values.findindex(@(v) v == inst.name)// Actual option value. Need to return only.
      }
    }
    return {
      actionText = actionText
      rows
    }
  }

  function updateSelectorView() {
    isForcedSelect = true
    foreach (idx, inst in stateList) {
      let selectorItems = optionsList.findvalue(@(o) o.name == inst.name)?.items
      let valBySelector = !selectorItems ? 0 : selectorItems.findindex(@(i) i.name == inst.name)
      this.scene.findObject(idx)?.setValue(valBySelector)
    }
    isForcedSelect = false
  }

  getActionBtn = @() this.scene.findObject(ACTION_BTN)

  function onUnderPopupClick() {
    ::showBtn(SELECTOR_OBJ, false, this.scene)
  }

  function onAction() {
    tmpStates = ::u.copy(stateList)
    updateSelectorView()
    ::showBtn(SELECTOR_OBJ, true, this.scene)
  }

  function onCancel() {
    ::showBtn(SELECTOR_OBJ, false, this.scene)
  }

  function onSelect(obj) {
    if (isForcedSelect)
      return

    let optObj = obj.getChild(obj.getValue())
    let val = ::get_option(obj.optType.tointeger()).values.findindex(@(t) t == optObj?.optName)
    // Need to reset duplicates for non-empty items only
    if (obj.isEmptyDefault && val != null) {
      let stateId = tmpStates.findindex(@(c) c.val == val)
      if (stateId && stateId != obj.id)
        this.scene.findObject(stateId).setValue(0)
    }

    tmpStates[obj.id] <- {
      optType = obj.optType.tointeger()
      name = optObj?.optName
      val = val
    }
  }

  function onApply() {
    stateList = ::u.copy(tmpStates)
    tmpStates = null
    local res = {}
    for (local i= 0; i < optionsList.len(); i++) {
      let state = stateList?[$"cb_{i}"]
      if (!state || state.val == null)
        continue

      let optType = state.optType
      if (!res?[optType])
        res[optType] <- []

      res[optType].append(::get_option(optType).values[state.val])
    }
    ::showBtn(SELECTOR_OBJ, false, this.scene)
    if (onActionFn)
      onActionFn(res)
  }
}

::gui_handlers.popupOptList <- popupOptList

return {
  addPopupOptList = @(params = {}) ::handlersManager.loadHandler(popupOptList, params)
}
