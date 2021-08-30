require("interop.nut").setHandlers()

local {showHelp, editorIsActive, showEntitySelect,
  showTemplateSelect, entitiesListUpdateTrigger} = require("state.nut")

local mainToolbar = require("mainToolbar.nut")
local entitySelect = require("entitySelect.nut")
local templateSelect = require("templateSelect.nut")
local attrPanel = require("attrPanel.nut")
local help = require("components/help.nut")(showHelp)
local cursors = require("components/cursors.nut")


return function() {
  if (!editorIsActive.value) {
    return {
      watch = editorIsActive
    }
  }

  return {
    size = [sw(100), sh(100)]
    cursor = cursors.normal
    watch = [
      editorIsActive
      showEntitySelect
      showTemplateSelect
      showHelp
      entitiesListUpdateTrigger
    ]

    children = [
      mainToolbar,
      attrPanel,
      (showEntitySelect.value && !showHelp.value ? entitySelect : null),
      (showTemplateSelect.value && !showHelp.value ? templateSelect : null),
      (showHelp.value ? help : null),
    ]
  }
}
