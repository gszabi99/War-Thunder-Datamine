from "%darg/ui_imports.nut" import *

let entity_editor = require_optional("entity_editor")
let { fileName } = require("%sqstd/path.nut")
let { editorIsActive, sceneListUpdateTrigger, edObjectFlagsUpdateTrigger } = require("state.nut")
let { getScenePrettyName, getSceneLoadTypeText } = require("daeditor_es.nut")
let { sortScenesByLoadType } = require("components/sceneSorting.nut")

let UNUSED = @(...) null


let allScenes = mkWatched(persist, "allScenes", [])

function updateAllScenes() {
  allScenes.set(entity_editor?.get_instance()?.getSceneImports() ?? [])
}


let sortedScenes = Computed(function() {
  let scenes = allScenes.get().map(@(scene, index) scene.__merge({ index }))
  scenes.sort(sortScenesByLoadType)
  return scenes
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
  UNUSED(edObjectFlagsUpdateTrigger)
  return sortedScenes.get().filter(@(scene) canSceneBeModified(scene))
})

sceneListUpdateTrigger.subscribe_with_nasty_disregard_of_frp_update(@(_v) updateAllScenes())

editorIsActive.subscribe_with_nasty_disregard_of_frp_update(function(on) {
  if (on) {
    updateAllScenes()
  }
})
updateAllScenes()

return {
  allScenes
  sortedScenes
  sceneIdMap
  allModifiableScenes
  updateAllScenes
  canSceneBeModified
  sceneToComboboxEntry
  sceneDisplayName
}
