from "%sqstd/ecs.nut" import *
from "%darg/ui_imports.nut" import *

let { selectedEntity, selectedEntities, selectedEntitiesSetKeyVal, selectedEntitiesDeleteKey, selectedCompName} = require("state.nut")









let defaultGetEntityExtraNameQuery = SqQuery("defaultGetEntityExtraNameQuery", {
  comps_ro = [["ri_extra__name", TYPE_STRING, null]]
})

let {
  get_entity_extra_name = @(eid) defaultGetEntityExtraNameQuery(eid, @(_eid, comp) comp.ri_extra__name)
} = require_optional("das.daeditor")


selectedEntities.subscribe(function(val) {
  if (val.len() == 1)
    selectedEntity(val.keys()[0])
  else
    selectedEntity(INVALID_ENTITY_ID)
})

selectedEntity.subscribe(function(_eid) {
  selectedCompName(null)
})

register_es("update_selected_entities", {
    onInit = @(eid, _comp) selectedEntitiesSetKeyVal(eid, true)
    onDestroy = @(eid, _comp) selectedEntitiesDeleteKey(eid)
  },
  { comps_rq = ["daeditor__selected"]}
)

function getEntityExtraName(eid) {
  let extraName = get_entity_extra_name?(eid) ?? ""

  return extraName.strip() == "" ? null : extraName
}

function getSceneLoadTypeText(v) {
  let loadTypeVal = type(v) == "int" || type(v) == "integer" ? v : v.loadType
  let loadType = (
    (loadTypeVal == 1) ? "COMMON" :
    (loadTypeVal == 2) ? "CLIENT" :
    (loadTypeVal == 3) ? "IMPORT" :
    "UNKNOWN"
  )
  return loadType
}

function getSceneId(loadType, index) {
  return (index << 2) | loadType
}

function getSceneIdOf(scene) {
  return getSceneId(scene.loadType, scene.index)
}

function getSceneIdLoadType(sceneId) {
  return (sceneId & (1 | 2))
}

function getSceneIdIndex(sceneId) {
  return (sceneId >> 2)
}

return {
  getEntityExtraName

  getSceneLoadTypeText
  getSceneId
  getSceneIdOf
  getSceneIdLoadType
  getSceneIdIndex
}