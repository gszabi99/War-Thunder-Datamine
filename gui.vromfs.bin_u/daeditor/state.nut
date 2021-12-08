from "%darg/ui_imports.nut" import *
import "%sqstd/ecs.nut" as ecs

local {getEditMode=null} = require_optional("daEditor4")
local {is_editor_activated=null, get_scene_filepath=null} = require_optional("entity_editor")
local selectedEntity = Watched(ecs.INVALID_ENTITY_ID)
local setSelectedEntity = @(_, eid, __) selectedEntity(eid)

ecs.register_es("findSelectedEntity", {
    onInit = setSelectedEntity,
  },
  { comps_rq = ["daeditor__selected"]}
)

return {
  showUIinEditor = mkWatched(persist, "showUIinEditor", false)
  editorIsActive = Watched(is_editor_activated?())
  selectedEntity
  scenePath = Watched(get_scene_filepath?())
  propPanelVisible = mkWatched(persist, "propPanelVisible", false)
  filterString = mkWatched(persist, "filterString", "")
  selectedCompName = Watched()
  showEntitySelect = mkWatched(persist, "showEntitySelect", false)
  showTemplateSelect = mkWatched(persist, "showTemplateSelect", false)
  showHelp = mkWatched(persist, "showHelp", false)
  entitiesListUpdateTrigger = mkWatched(persist, "entitiesListUpdateTrigger", 0)
  de4editMode = Watched(getEditMode?())
  extraPropPanelCtors = Watched([])
}

