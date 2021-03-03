local {editorIsActive, selectedEntity, propPanelVisible, entitiesListUpdateTrigger, showTemplateSelect, de4editMode, selectedCompName} = require("state.nut")

local daEditor4 = require("daEditor4")
local entity_editor = require("entity_editor")


local function setHandlers() {
  daEditor4.setHandlers({
    function onDe4SetEditMode(mode) {
      de4editMode.update(mode)
    }
  })

  entity_editor.setHandlers({
    function onDe4ShowAssetsWnd(on) {
      showTemplateSelect.update(on)
    }


    function onEditorActivated(on) {
      editorIsActive.update(on)
    }


    function onEntitySelected(eid) {
      if (eid == selectedEntity.value)
        return

      selectedEntity.update(eid)
      selectedCompName.update(null)
    }


    function togglePropPanel() {
      propPanelVisible.update(!propPanelVisible.value)
    }


    function onEntityAdded(eid) {
      entitiesListUpdateTrigger(entitiesListUpdateTrigger.value+1)
    }


    function onEntityRemoved(eid) {
      entitiesListUpdateTrigger(entitiesListUpdateTrigger.value+1)
    }
  })
}

return {
  setHandlers = setHandlers
}
