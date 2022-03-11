let {editorIsActive, editorFreeCam, entitiesListUpdateTrigger, showTemplateSelect, de4editMode, de4workMode} = require("state.nut")

let daEditor4 = require("daEditor4")
let entity_editor = require("entity_editor")

let {isFreeCamMode=null} = daEditor4
let {DE4_MODE_CREATE_ENTITY} = entity_editor


let function setHandlers() {
  daEditor4.setHandlers({
    function onDe4SetWorkMode(mode) {
      de4workMode(mode)
    }
    function onDe4SetEditMode(mode) {
      de4editMode(mode)
      showTemplateSelect(mode == DE4_MODE_CREATE_ENTITY)
    }
  })

  entity_editor.setHandlers({
    function onEditorActivated(on) {
      editorIsActive.update(on)
    }

    function onEditorChanged() {
      editorFreeCam.update(isFreeCamMode?() ?? false)
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
  setHandlers
}
