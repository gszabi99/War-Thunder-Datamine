local {showTemplateSelect} = require("state.nut")
local {colors} = require("components/style.nut")
local textButton = require("components/textButton.nut")
local nameFilter = require("components/nameFilter.nut")
local scrollbar = require("daRg/components/scrollbar.nut")
local entity_editor = require("entity_editor")
local daEditor4 = require("daEditor4")
local {DE4_MODE_SELECT} = daEditor4


local selectedItem = Watched(null)
local filterText = Watched("")
local templatePostfixText = Watched("")

local scrollHandler = ScrollHandler()


local function scrollByName(text) {
  scrollHandler.scrollToChildren(function(desc) {
    return ("tpl_name" in desc) && desc.tpl_name.indexof(text)!=null
  }, 2, false, true)
}

local function scrollBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("tpl_name" in desc) && desc.tpl_name==selectedItem.value
  }, 2, false, true)
}

local function doSelectTemplate(tpl_name) {
  selectedItem(tpl_name)
  if (selectedItem.value) {
    local finalTemplateName = selectedItem.value + templatePostfixText.value
    entity_editor.get_instance().selectEcsTemplate(finalTemplateName)
  }
}

local filter = nameFilter(filterText, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterText(text)

    if (selectedItem.value && text.len() && selectedItem.value.indexof(text)!=null)
      scrollBySelection()
    else if (text.len())
      scrollByName(text)
    else
      scrollBySelection()
  }

  function onEscape() {
    filterText("")
  }
})

local templPostfix = nameFilter(templatePostfixText, {
  placeholder = "Template postfix"

  function onChange(text) {
    templatePostfixText(text)
  }

  function onEscape() {
    templatePostfixText("")
  }
})

local function listRow(tpl_name, idx) {
  local stateFlags = Watched(0)

  return function() {
    local isSelected = selectedItem.value == tpl_name

    local color
    if (isSelected) {
      color = colors.Active
    } else {
      color = (stateFlags.value & S_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    }

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color = color
      behavior = Behaviors.Button
      tpl_name = tpl_name

      watch = stateFlags
      onClick = @() doSelectTemplate(tpl_name)
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_DTEXT
        text = tpl_name
        margin = sh(0.5)
      }
    }
  }
}



local function dialogRoot() {
  local templates = entity_editor.get_instance().getEcsTemplates()

  local function listContent() {
    local rows = []
    local idx = 0
    foreach (tplName in templates) {
      if (!filterText.value.len() || tplName.indexof(filterText.value)!=null) {
        rows.append(listRow(tplName, idx))
      }
    }

    return {
      watch = [selectedItem, filterText]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = rows
      behavior = Behaviors.Button
    }
  }


  local scrollList = scrollbar.makeVertScroll(listContent)


  local function doCancel() {
    showTemplateSelect(false)
    filterText("")
    daEditor4.setEditMode(DE4_MODE_SELECT)
  }


  return {
    size = [sw(15), sh(75)]
    hplace = ALIGN_LEFT
    vplace = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = colors.ControlBg
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    behavior = Behaviors.Button
    key = "template_select"
    padding = sh(0.5)
    gap = sh(0.5)

    children = [
      filter
      {
        size = flex()
        children = scrollList
      }
      templPostfix
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("Close", doCancel, {hotkeys=["^Esc"]})
        ]
      }
    ]
  }
}


return dialogRoot
