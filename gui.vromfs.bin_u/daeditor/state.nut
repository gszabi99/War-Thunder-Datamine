from "%darg/ui_imports.nut" import *
import "ecs"

local {getEditMode=null} = require_optional("daEditor4")
local {is_editor_activated=null, get_scene_filepath=null} = require_optional("entity_editor")
local selectedEntity = Watched(ecs.INVALID_ENTITY_ID)
local setSelectedEntity = @(_, eid, __) selectedEntity(eid)
//local unsetSelectedEntity = @(...) selectedEntity(INVALID_ENTITY_ID)
local register_entity_system = ecs?.___register_entity_system_internal___ ?? ecs?.register_entity_system ?? @(...) null

register_entity_system("findSelectedEntity", {
    [ecs.EventEntityCreated] = setSelectedEntity,
    [ecs.EventScriptReloaded] = setSelectedEntity,
    [ecs.EventComponentsAppear] = setSelectedEntity,
  },
  { comps_rq = ["daeditor.selected"]}, {}
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

