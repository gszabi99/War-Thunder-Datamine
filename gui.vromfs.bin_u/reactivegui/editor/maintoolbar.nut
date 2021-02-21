local {showEntitySelect, propPanelVisible, showHelp, de4editMode, showUI} = require("state.nut")
local pictureButton = require("components/pictureButton.nut")
local cursors =  require("components/cursors.nut")
local daEditor4 = require("daEditor4")
local entity_editor = require("entity_editor")
local {DE4_MODE_MOVE, DE4_MODE_ROTATE, DE4_MODE_SCALE, DE4_MODE_SELECT, getEditMode, setEditMode} = daEditor4
local {DE4_MODE_CREATE_ENTITY} = entity_editor
//local PictureAtlas = require("daRg/helpers/pictureAtlas.nut")
//local toolbarImages = PictureAtlas("!ui/editor/images/") //would be better to replace images with canvas or svg

local function toolbarButton(image, action, tooltip_text, checked=null) {
  local function onHover(on) {
    cursors.setTooltip(on ? tooltip_text : null)
  }
  local defParams = {
    imageMargin = sh(0.5)
    action = action
    checked = checked
    onHover = onHover
  }
  local params = (::type(image)=="table") ? defParams.__merge(image) : defParams.__merge({image=image})
  return pictureButton(params)
}

local function modeButton(image, mode, tooltip_text, next_action=null) {
  local params = (::type(image)=="table") ? image : {image=image}
  params = params.__merge({
    checked = mode==getEditMode()
    imageMargin = sh(0.5)
    function onHover(on) {
      cursors.setTooltip(on ? tooltip_text : null)
    }
    function action() {
      showEntitySelect.update(false)
      daEditor4.setEditMode(mode)
      if (next_action)
        next_action()
    }
  })
  return pictureButton(params)
}


local separator = {
  rendObj = ROBJ_SOLID
  color = Color(100, 100, 100, 100)
  size = [1, sh(3)]
  margin = [0, sh(0.5)]
}


local function mainToolbar() {
  local function toggleEntitySelect() {
    if (getEditMode() == DE4_MODE_CREATE_ENTITY)
      setEditMode(DE4_MODE_SELECT)
    showEntitySelect.update(!showEntitySelect.value);
  }
  local togglePropPanel = @() propPanelVisible.update(!propPanelVisible.value)
  local toggleHelp = @() showHelp.update(!showHelp.value)


  return {
    size = [sw(100), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = Color(150, 150, 150, 250)
    watch = de4editMode
    valign = ALIGN_CENTER
    padding =hdpx(4)

    children = [
      {size=[sw(10), 1]} //< padding to move away from FPS counter

      modeButton({fa="mouse-pointer", color=Color(0,0,0)}, DE4_MODE_SELECT, "Select")
      modeButton({fa="arrows"}, DE4_MODE_MOVE, "Move")
      modeButton({fa="undo" color=Color(120,120,255)}, DE4_MODE_ROTATE, "Rotate") //rotate or mirror, make blue
      modeButton({fa="arrows-alt" color=Color(200,200,100)}, DE4_MODE_SCALE, "Scale")
      modeButton({fa="smile-o", color=Color(255,255,120)}, DE4_MODE_CREATE_ENTITY, "Create entity")
      separator
      toolbarButton({fa="folder-open-o"}, toggleEntitySelect, "Select by name", showEntitySelect.value)
      toolbarButton({fa="file-text-o"}, togglePropPanel, "Property panel", propPanelVisible.value)
      toolbarButton({fa="save"}, @() entity_editor.get_instance().saveObjects(""), "Save")
      toolbarButton({fa="question"}, toggleHelp, "Help", showHelp.value)
      toolbarButton({fa="envelope"}, @() entity_editor.get_instance().hideSelectedTemplate(), "Hide")
      toolbarButton({fa="envelope-open"}, @() entity_editor.get_instance().unhideAll(), "Unhide all")
      separator
      toolbarButton({fa="eye"}, @() showUI(!showUI.value), "Switch UI visibility")
    ]

    hotkeys = [
      ["L.Alt H", toggleEntitySelect],
      ["F1", toggleHelp],
    ]
  }
}


return mainToolbar
