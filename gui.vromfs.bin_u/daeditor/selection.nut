from "%darg/ui_imports.nut" import *
import "%sqstd/ecs.nut" as ecs

let entity_editor = require_optional("entity_editor")
let { sceneIdMap } = require("sceneModel.nut")



let selection = mkWatched(persist, "selection", { scenes = {}, entities = {} })


function isObjMarked(sel, obj) {
  return obj.id in (obj.isEntity ? sel.entities : sel.scenes)
}

function matchEntityByScene(eid, markedScenes) {
  let id = entity_editor?.get_instance().getEntityRecordSceneId(eid)
  if (id in markedScenes) {
    return true
  }
  return entity_editor?.get_instance().isSceneEntity(eid)
}

function setObjMark(sel, obj, on) {
  let ids = obj.isEntity ? sel.entities : sel.scenes
  if (on) {
    ids[obj.id] <- true
  }
  else {
    ids.$rawdelete(obj.id)
  }
}

function markObjects(objs, on) {
  selection.mutate(function(sel) {
    foreach (obj in objs) {
      setObjMark(sel, obj, on)
    }
  })
}

function toggleObject(obj) {
  selection.mutate(@(sel) setObjMark(sel, obj, !isObjMarked(sel, obj)))
}

function clearSelection() {
  selection.set({ scenes = {}, entities = {} })
}

function setSelection(objs) {
  selection.set(objs.reduce(function(sel, obj) {
    setObjMark(sel, obj, true)
    return sel
  }, { scenes = {}, entities = {} }))
}

let markedSceneCount = Computed(@() selection.get().scenes.len())

let selectedItems = Computed(function() {
  let sel = selection.get()
  let scenes = sceneIdMap.get()
  let items = sel.scenes.keys().map(@(id) { id, isEntity = false, loadType = scenes?[id].loadType ?? 0 })
  items.extend(sel.entities.keys().map(@(id) { id, isEntity = true }))
  return items
})

let hasSelection = Computed(@() selectedItems.get().len() != 0)

function applyToEditor() {
  entity_editor?.get_instance().selectObjects(selectedItems.get())
}

sceneIdMap.subscribe_with_nasty_disregard_of_frp_update(function(scenes) {
  let gone = selection.get().scenes.keys().filter(@(id) id != ecs.INVALID_SCENE_ID && id not in scenes)
  if (gone.len() != 0) {
    selection.mutate(function(sel) {
      foreach (id in gone) {
        sel.scenes.$rawdelete(id)
      }
    })
  }
})

return {
  selection
  selectedItems
  hasSelection
  markedSceneCount

  isObjMarked
  matchEntityByScene

  markObjects
  toggleObject
  setSelection
  clearSelection
  applyToEditor
}
