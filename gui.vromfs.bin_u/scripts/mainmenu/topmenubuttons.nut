from "%scripts/dagui_library.nut" import *
from "%scripts/mainmenu/topMenuConsts.nut" import TOP_MENU_ELEMENT_TYPE
let topMenuButtonsList = require("%scripts/mainmenu/topMenuButtonsList.nut")
let { openOptionsWnd } = require("%scripts/options/handlers/optionsWnd.nut")
let { gui_start_controls } = require("%scripts/controls/startControls.nut")

let cache = { byId = {} }

let getButtonConfigById = function(id) {
  if (!(id in cache.byId)) {
    let buttonCfg = topMenuButtonsList.get().findvalue(@(t) t.id == id)
    cache.byId[id] <- buttonCfg ?? topMenuButtonsList.get().UNKNOWN
  }
  return cache.byId[id]
}

let template = {
  id = ""
  text = @() ""
  tooltip = @() ""
  image = @() null
  link = @() null
  isLink = @() false
  isFeatured = @() false
  needDiscountIcon = false
  unseenIcon = null
  onClickFunc = @(_obj, _handler = null) null
  onChangeValueFunc = @(_value) null
  isHidden = @(_handler = null) false
  isVisualDisabled = @() false
  isInactiveInQueue = false
  elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  isButton = @() this.elementType == TOP_MENU_ELEMENT_TYPE.BUTTON
  isDelayed = true
  checkbox = @() this.elementType == TOP_MENU_ELEMENT_TYPE.CHECKBOX 
  isEmptyButton = @() this.elementType == TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  funcName = @() this.isButton() ? "onClick" : this.checkbox() ? "onChangeCheckboxValue" : null
}

function fillButtonConfig(buttonCfg, name) {
  return template.__merge(buttonCfg.__merge({
    id = name.tolower()
    typeName = name
  }))
}

let addButtonConfig = @(newBtnConfig, name)
  topMenuButtonsList.mutate(@(v) v[name] <- fillButtonConfig(newBtnConfig, name))

let defaultButtonsConfig = { 
  UNKNOWN = {}
  OPTIONS = {
    text = @() "#mainmenu/btnGameplay"
    onClickFunc = @(_obj, _handler) openOptionsWnd()
  }
  CONTROLS = {
    text = @() "#mainmenu/btnControls"
    onClickFunc = @(...) gui_start_controls()
    isHidden = @(...) !hasFeature("ControlsAdvancedSettings")
  }
  EMPTY = {
    elementType = TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  }
}

defaultButtonsConfig.each(addButtonConfig)

return {
  getButtonConfigById = getButtonConfigById
  addButtonConfig
}
