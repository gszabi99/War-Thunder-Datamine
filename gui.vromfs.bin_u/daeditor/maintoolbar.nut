from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
let {showEntitySelect, propPanelVisible, propPanelClosed, showHelp, de4editMode, de4workMode, de4workModes, showUIinEditor} = require("state.nut")
let pictureButton = require("components/pictureButton.nut")
let combobox = require("%darg/components/combobox.nut")
let cursors =  require("components/cursors.nut")
let daEditor4 = require("daEditor4")
let {DE4_MODE_CREATE_ENTITY, get_instance} = require("entity_editor")
let {DE4_MODE_MOVE, DE4_MODE_ROTATE, DE4_MODE_SCALE, DE4_MODE_SELECT, getEditMode, setEditMode} = daEditor4

let function toolbarButton(image, action, tooltip_text, checked=null) {
  let function onHover(on) {
    cursors.setTooltip(on ? tooltip_text : null)
  }
  let defParams = {
    imageMargin = fsh(0.5)
    action
    checked
    onHover
  }
  let params = (type(image)=="table") ? defParams.__merge(image) : defParams.__merge({image})
  return pictureButton(params)
}

let function modeButton(image, mode, tooltip_text, next_mode=null, next_action=null) {
  local params = (type(image)=="table") ? image : {image}
  params = params.__merge({
    checked = mode==getEditMode()
    imageMargin = fsh(0.5)
    function onHover(on) {
      cursors.setTooltip(on ? tooltip_text : null)
    }
    function action() {
      showEntitySelect.update(false)
      if (next_mode && mode==getEditMode())
        mode = next_mode
      daEditor4.setEditMode(mode)
      if (next_action)
        next_action()
    }
  })
  return pictureButton(params)
}


let separator = {
  rendObj = ROBJ_SOLID
  color = Color(100, 100, 100, 100)
  size = [1, fsh(3)]
  margin = [0, fsh(0.5)]
}

let svg = @(name) {image = $"!%daeditor/images/{name}.svg"} //Atlas is not working %daeditor/editor#
let function mainToolbar() {
  let function toggleEntitySelect() {
    if (getEditMode() == DE4_MODE_CREATE_ENTITY)
      setEditMode(DE4_MODE_SELECT)
    showEntitySelect.update(!showEntitySelect.value);
  }
  let function toggleCreateEntityMode() {
    showEntitySelect.update(false)
    local mode = DE4_MODE_CREATE_ENTITY
    if (DE4_MODE_CREATE_ENTITY==getEditMode())
      mode = DE4_MODE_SELECT
    daEditor4.setEditMode(mode)
  }
  let togglePropPanel = function() {
    propPanelClosed(propPanelVisible.value)
    propPanelVisible(!propPanelVisible.value)
  }
  let toggleHelp = @() showHelp.update(!showHelp.value)

  return {
    size = [sw(100), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    rendObj = ROBJ_WORLD_BLUR
    color = Color(150, 150, 150, 255)
    watch = [de4editMode, propPanelVisible, de4workMode, de4workModes]
    valign = ALIGN_CENTER
    padding =hdpx(4)

    children = [
//      comp(Watch(scenePath), txt(scenePath.value, {color = Color(170,170,170), padding=[0, hdpx(10)], maxWidth = sw(15)}), ClipChildren)
      toolbarButton(svg("select_by_name"), toggleEntitySelect, "Select by name", showEntitySelect.value)
      separator
      modeButton(svg("select"), DE4_MODE_SELECT, "Select")
      modeButton(svg("move"), DE4_MODE_MOVE, "Move")
      modeButton(svg("rotate"), DE4_MODE_ROTATE, "Rotate") //rotate or mirror, make blue
      modeButton(svg("scale"), DE4_MODE_SCALE, "Scale")
      modeButton(svg("create"), DE4_MODE_CREATE_ENTITY, "Create entity", DE4_MODE_SELECT)
      separator
      toolbarButton(svg("properties"), togglePropPanel, "Property panel", propPanelVisible.value)
      toolbarButton(svg("hide"), @() get_instance().hideSelectedTemplate(), "Hide")
      toolbarButton(svg("show"), @() get_instance().unhideAll(), "Unhide all")
      separator
      toolbarButton(svg("gui_toggle"), @() showUIinEditor(!showUIinEditor.value), "Switch UI visibility")
      separator
      toolbarButton(svg("save"), @() get_instance().saveObjects(""), "Save")
      toolbarButton(svg("help"), toggleHelp, "Help", showHelp.value)

      de4workModes.value.len() <= 1 ? null : separator
      de4workModes.value.len() <= 1 ? null : {
        size = [hdpx(100),fontH(100)]
        children = combobox(de4workMode, de4workModes)
      }
    ]

    hotkeys = [
      ["L.Alt H", toggleEntitySelect],
      ["Tab", toggleEntitySelect],
      ["T", toggleCreateEntityMode],
      ["F1", toggleHelp],
      ["P", togglePropPanel]
    ]
  }
}


return mainToolbar
