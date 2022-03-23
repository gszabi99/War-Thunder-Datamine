let {sh, sw, set_kb_focus} = require("daRg")
require("interop.nut").setHandlers()
require("daeditor_es.nut")

let {showHelp, editorIsActive, editorFreeCam, showEntitySelect,
  showTemplateSelect, entitiesListUpdateTrigger} = require("state.nut")

editorIsActive.subscribe(function(v){ if(v == false) set_kb_focus(null) })
editorFreeCam.subscribe(function(v){ if(v == true) set_kb_focus(null) })

let mainToolbar = require("mainToolbar.nut")
let entitySelect = require("entitySelect.nut")
let templateSelect = require("templateSelect.nut")
let attrPanel = require("attrPanel.nut")
let help = require("components/help.nut")(showHelp)
let cursors = require("components/cursors.nut")
let {modalWindowsComponent} = require("components/modalWindows.nut")
let {msgboxComponent} = require("editor_msgbox.nut")

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
      (showEntitySelect.value ? entitySelect : null),
      (showTemplateSelect.value ? templateSelect : null),
      (showHelp.value ? help : null),
      modalWindowsComponent,
      msgboxComponent,
    ]
  }
}
