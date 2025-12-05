from "%sqstd/ecs.nut" import *
from "%darg/ui_imports.nut" import *

let entity_editor = require_optional("entity_editor")
let { selectedEntity, selectedEntities, selectedEntitiesSetKeyVal, selectedEntitiesDeleteKey,
      selectedCompName, markedScenes, sceneIdMap } = require("state.nut")
let { fileName } = require("%sqstd/path.nut")









let defaultGetEntityExtraNameQuery = SqQuery("defaultGetEntityExtraNameQuery", {
  comps_ro = [["ri_extra__name", TYPE_STRING, null]]
})

let {
  get_entity_extra_name = @(eid) defaultGetEntityExtraNameQuery(eid, @(_eid, comp) comp.ri_extra__name)
} = require_optional("das.daeditor")


selectedEntities.subscribe_with_nasty_disregard_of_frp_update(function(val) {
  if (val.len() == 1)
    selectedEntity.set(val.keys()[0])
  else
    selectedEntity.set(INVALID_ENTITY_ID)
})

selectedEntity.subscribe_with_nasty_disregard_of_frp_update(function(_eid) {
  selectedCompName.set(null)
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

const loadTypeConst = 4
let sceneGenerated = {
  id = -1
  asText = "[GENERATED]"
  
  loadType = loadTypeConst
  index = -2
  entityCount = -2
  path = "\0"
}

let sceneSaved = {
  id = -2
  asText = "[ALL FILES]"
  
  loadType = loadTypeConst
  index = -1
  entityCount = -1
  path = "\0\0"
}

function getNumMarkedScenes() {
  local nSel = 0
  foreach (_sceneId, marked in markedScenes.get()) {
    if (marked)
      ++nSel
  }
  return nSel
}

function matchSceneEntity(eid, saved, generated) {
  local isSaved = entity_editor?.get_instance().isSceneEntity(eid)
  return (saved && isSaved) || (generated && !isSaved)
}

function matchEntityByScene(eid, saved, generated) {
  local id = entity_editor?.get_instance().getEntityRecordSceneId(eid)
  if (markedScenes.get()?[id])
    return true
  return matchSceneEntity(eid, saved, generated)
}

function getScenePrettyName(loadType, index) {
  if (loadType == 3) {
    return entity_editor?.get_instance().getScenePrettyName(index) ?? ""
  }

  return ""
}

function sceneToComboboxEntry(scene) {
  if (scene.importDepth == 0 && !scene.hasParent) {
    return "MAIN"
  }

  local prettyName = getScenePrettyName(scene.loadType, scene.id)
  local strippedPath = fileName(scene.path)
  local loadType = getSceneLoadTypeText(scene)
  return $"{loadType}:{scene.id}:{prettyName.len() == 0 ? strippedPath : $"{prettyName} ({strippedPath})"}"
}

function canSceneBeModified(scene) {
  if (scene == null) {
    return false
  }

  while (scene?.loadType != null) {
    if (scene.loadType != 3 || (scene.importDepth != 0 && !entity_editor?.get_instance().isChildScene(3, scene.id))) {
      return false
    }

    scene = sceneIdMap?.get()[scene.parent]
  }

  return true
}

return {
  getEntityExtraName

  getSceneLoadTypeText

  loadTypeConst
  sceneGenerated
  sceneSaved

  getNumMarkedScenes
  matchSceneEntity
  matchEntityByScene

  getScenePrettyName
  sceneToComboboxEntry
  canSceneBeModified
}