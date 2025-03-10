from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsCtors.nut" import create_option_combobox

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { USEROPT_CLUSTERS } = require("%scripts/options/optionsExtNames.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")

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

local popupOptList = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupOptList.tpl"

  stateList            = null
  tmpStates            = null
  resetId              = null
  isForcedSelect       = false

  
  actionText           = null
  optionsList          = null
  onActionFn           = null

  function getSceneTplView() {
    this.stateList = {}
    local rows = []
    foreach (idx, inst in this.optionsList) {
      let { title, exceptions = [] } = inst
      let objId = $"cb_{idx}"
      let option = get_option(USEROPT_CLUSTERS)
      let items = [deafaulEmptyOpt].extend(option.items)
        .filter(@(v) !exceptions.contains(v.text) && !(v?.isAuto ?? false))
      let valBySelector = inst.name
        ? items.findindex(@(v) v.name == inst.name)
        : 0
      rows.append({
        title
        options = create_option_combobox(objId, items, valBySelector, null, false)
      })
      inst.items <- items
      this.stateList[objId] <- {
        name = inst.name
        val = option.values
          .filter(@(v) v != "auto")
          .findindex(@(v) v == inst.name) 
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
    showObjById(SELECTOR_OBJ, false, this.scene)
  }

  function onAction() {
    this.tmpStates = u.copy(this.stateList)
    this.updateSelectorView()
    showObjById(SELECTOR_OBJ, true, this.scene)
  }

  function onCancel() {
    showObjById(SELECTOR_OBJ, false, this.scene)
  }

  function onSelect(obj) {
    if (this.isForcedSelect)
      return

    let optObj = obj.getChild(obj.getValue())
    let val = get_option(USEROPT_CLUSTERS).values
      .filter(@(v) v != "auto")
      .findindex(@(t) t == optObj?.optName)
    
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
    this.stateList = u.copy(this.tmpStates)
    this.tmpStates = null
    let clusterOpt = get_option(USEROPT_CLUSTERS)
    let res = []
    for (local i = 0; i < this.optionsList.len(); i++) {
      let state = this.stateList?[$"cb_{i}"]
      if (!state || state.val == null)
        continue

      res.append(clusterOpt.values[state.val])
    }
    showObjById(SELECTOR_OBJ, false, this.scene)
    if (this.onActionFn)
      this.onActionFn(res)
  }
}

gui_handlers.popupOptList <- popupOptList

return {
  addPopupOptList = @(params = {}) handlersManager.loadHandler(popupOptList, params)
}
