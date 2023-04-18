//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { cutPrefix } = require("%sqstd/string.nut")

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
      let { title, exceptions = [] } = inst
      let objId = $"cb_{idx}"
      let option = ::get_option(::USEROPT_CLUSTER)
      let items = [deafaulEmptyOpt].extend(option.items)
        .filter(@(v) !exceptions.contains(v.text) && !(v?.isAuto ?? false))
      let valBySelector = inst.name
        ? items.findindex(@(v) v.name == inst.name)
        : 0
      rows.append({
        title
        options = ::create_option_combobox(objId, items, valBySelector, null, false)
      })
      inst.items <- items
      this.stateList[objId] <- {
        name = inst.name
        val = option.values
          .filter(@(v) v != "auto")
          .findindex(@(v) v == inst.name) // Actual option value. Need to return only.
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
      let selectorItems = this.optionsList?[cutPrefix(idx, "cb_").tointeger()].items
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
    let val = ::get_option(::USEROPT_CLUSTER).values
      .filter(@(v) v != "auto")
      .findindex(@(t) t == optObj?.optName)
    // Need to reset duplicates for non-empty items only
    if (val != null) {
      let stateId = this.tmpStates.findindex(@(c) c.val == val)
      if (stateId && stateId != obj.id)
        this.scene.findObject(stateId).setValue(0)
    }

    this.tmpStates[obj.id] <- {
      name = optObj?.optName
      val = val
    }
  }

  function onApply() {
    this.stateList = ::u.copy(this.tmpStates)
    this.tmpStates = null
    let clusterOpt = ::get_option(::USEROPT_CLUSTER)
    let res = []
    for (local i = 0; i < this.optionsList.len(); i++) {
      let state = this.stateList?[$"cb_{i}"]
      if (!state || state.val == null)
        continue

      res.append(clusterOpt.values[state.val])
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
