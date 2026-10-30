from "%darg/ui_imports.nut" import *
from "%sqstd/underscore.nut" import isEqual

let entity_editor = require_optional("entity_editor")
let { fileName } = require("%sqstd/path.nut")
let { edObjectFlagsUpdateTrigger, DEPENDS_ON } = require("state.nut")
let { getScenePrettyName, getSceneLoadTypeText } = require("daeditor_es.nut")
let { sortScenesByLoadType } = require("components/sceneSorting.nut")



let { sceneTree = Watched(freeze({ scenes = [], entries = {}, entityCounts = {}, freeEntities = [] })) } = entity_editor




let sortedScenes = Computed(function(prev) {
  let scenes = sceneTree.get().scenes.map(@(scene, index) scene.__merge({ index }))
  scenes.sort(sortScenesByLoadType)
  return isEqual(scenes, prev) ? prev : scenes
})

let sceneIdMap = Computed(@() sortedScenes.get().map(@(scene) [scene.id, scene]).totable())

function sceneDisplayName(scene): string {
  let prettyName = getScenePrettyName(scene.id)
  let strippedPath = fileName(scene.path)
  return prettyName.len() == 0 ? strippedPath : $"{prettyName} ({strippedPath})"
}

function sceneToComboboxEntry(scene): string {
  if (scene.importDepth == 0 && !scene.hasParent) {
    return "MAIN"
  }
  return $"{getSceneLoadTypeText(scene)}:{scene.id}:{sceneDisplayName(scene)}"
}

function canSceneBeModified(scene): bool {
  if (scene == null) {
    return false
  }

  while (scene?.loadType != null) {
    if (scene.loadType != 3 || (scene.importDepth != 0 && !entity_editor?.get_instance().isChildScene(scene.id))) {
      return false
    }

    if (entity_editor?.get_instance()?.isSceneInLockedHierarchy(scene.id)) {
      return false
    }

    scene = sceneIdMap.get()?[scene.parent]
  }

  return true
}

let allModifiableScenes = Computed(function() {
  DEPENDS_ON(edObjectFlagsUpdateTrigger)
  return sortedScenes.get().filter(@(scene) canSceneBeModified(scene))
})

return {
  sceneTree
  sortedScenes
  sceneIdMap
  allModifiableScenes
  canSceneBeModified
  sceneToComboboxEntry
  sceneDisplayName
}
