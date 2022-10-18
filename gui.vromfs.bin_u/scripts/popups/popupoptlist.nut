const SELECTOR_OBJ = "selector_obj"
const ACTION_BTN = "action_btn"

let deafaulEmptyOpt = {
  text = ::loc("options/aaaNone")
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
  resetId              = null

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
      let val = inst.name
        ? option.values.findindex(@(v) v == inst.name)
        : isEmptyDefault ? 0 : option.value
      rows.append({
        title
        optType
        isEmptyDefault
        options = ::create_option_combobox(objId, items, val, null, false)
      })
      stateList[objId] <- {
        optType
        val
      }
    }
    return {
      actionText = actionText
      rows
    }
  }

  getActionBtn = @() scene.findObject(ACTION_BTN)

  function onUnderPopupClick() {
    ::showBtn(SELECTOR_OBJ, false, scene)
  }

  function onAction() {
    ::showBtn(SELECTOR_OBJ, true, scene)
  }

  function onCancel() {
    ::showBtn(SELECTOR_OBJ, false, scene)
  }

  function onSelect(obj) {
    let optObj = obj.getChild(obj.getValue())
    let val = ::get_option(obj.optType.tointeger()).values.findindex(@(t) t == optObj?.optName)
    let stateId = stateList.findindex(@(c) c.val == val)
    if (obj.isEmptyDefault && stateId && stateId != obj.id) {
      scene.findObject(stateId).setValue(0)
      stateList.rawdelete(stateId)
    }

    stateList[obj.id] <- {
      optType = obj.optType.tointeger()
      val = val
    }
  }

  function onApply() {
    local res = {}
    for (local i= 0; i < optionsList.len(); i++) {
      let state = stateList?[$"cb_{i}"]
      if (!state || !state.val)
        continue

      let optType = state.optType
      if (!res?[optType])
        res[optType] <- []

      res[optType].append(::get_option(optType).values[state.val])
    }
    ::showBtn(SELECTOR_OBJ, false, scene)
    if (onActionFn)
      onActionFn(res)
  }
}

::gui_handlers.popupOptList <- popupOptList

return {
  addPopupOptList = @(params = {}) ::handlersManager.loadHandler(popupOptList, params)
}
