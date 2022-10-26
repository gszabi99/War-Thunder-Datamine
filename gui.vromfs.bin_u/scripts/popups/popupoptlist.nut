from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

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
  sceneTplName         = "%gui/popup/popupOptList.tpl"

  stateList            = null
  tmpStates            = null
  resetId              = null
  isForcedSelect       = false

  //init params
  actionText           = null
  optionsList          = null
  onActionFn           = null

  function getSceneTplView() {
    this.stateList = {}
    local rows = []
    foreach (idx, inst in this.optionsList) {
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
      this.stateList[objId] <- {
        optType
        name = inst.name
        val = option.values.findindex(@(v) v == inst.name)// Actual option value. Need to return only.
      }
    }
    return {
      actionText = this.actionText
      rows
    }
  }

  function updateSelectorView() {
    this.isForcedSelect = true
    foreach (idx, inst in this.stateList) {
      let selectorItems = this.optionsList.findvalue(@(o) o.name == inst.name)?.items
      let valBySelector = !selectorItems ? 0 : selectorItems.findindex(@(i) i.name == inst.name)
      this.scene.findObject(idx)?.setValue(valBySelector)
    }
    this.isForcedSelect = false
  }

  getActionBtn = @() this.scene.findObject(ACTION_BTN)

  function onUnderPopupClick() {
    ::showBtn(SELECTOR_OBJ, false, this.scene)
  }

  function onAction() {
    this.tmpStates = ::u.copy(this.stateList)
    this.updateSelectorView()
    ::showBtn(SELECTOR_OBJ, true, this.scene)
  }

  function onCancel() {
    ::showBtn(SELECTOR_OBJ, false, this.scene)
  }

  function onSelect(obj) {
    if (this.isForcedSelect)
      return

    let optObj = obj.getChild(obj.getValue())
    let val = ::get_option(obj.optType.tointeger()).values.findindex(@(t) t == optObj?.optName)
    // Need to reset duplicates for non-empty items only
    if (obj.isEmptyDefault && val != null) {
      let stateId = this.tmpStates.findindex(@(c) c.val == val)
      if (stateId && stateId != obj.id)
        this.scene.findObject(stateId).setValue(0)
    }

    this.tmpStates[obj.id] <- {
      optType = obj.optType.tointeger()
      name = optObj?.optName
      val = val
    }
  }

  function onApply() {
    this.stateList = ::u.copy(this.tmpStates)
    this.tmpStates = null
    local res = {}
    for (local i= 0; i < this.optionsList.len(); i++) {
      let state = this.stateList?[$"cb_{i}"]
      if (!state || state.val == null)
        continue

      let optType = state.optType
      if (!res?[optType])
        res[optType] <- []

      res[optType].append(::get_option(optType).values[state.val])
    }
    ::showBtn(SELECTOR_OBJ, false, this.scene)
    if (this.onActionFn)
      this.onActionFn(res)
  }
}

::gui_handlers.popupOptList <- popupOptList

return {
  addPopupOptList = @(params = {}) ::handlersManager.loadHandler(popupOptList, params)
}
