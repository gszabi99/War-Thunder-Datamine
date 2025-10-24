from "string" import format
from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
from "%sqstd/ecs.nut" import *

let entity_editor = require_optional("entity_editor")
let { LoadedScenesWndId, selectedEntities, markedScenes, de4workMode, allScenesWatcher,
  getAllScenes, updateAllScenes, sceneIdMap, sceneListUpdateTrigger } = require("state.nut")
let { colors } = require("components/style.nut")
let textButton = require("components/textButton.nut")
let nameFilter = require("components/nameFilter.nut")
let { makeVertScroll } = require("%daeditor/components/scrollbar.nut")
let textInput = require("%daeditor/components/textInput.nut")
let { getSceneLoadTypeText, loadTypeConst, sceneGenerated, sceneSaved, getNumMarkedScenes, matchSceneEntity, matchEntityByScene,
   getScenePrettyName } = require("%daeditor/daeditor_es.nut")
let { defaultScenesSortMode, mkSceneSortModeButton } = require("components/mkSortSceneModeButton.nut")
let { addModalWindow, removeModalWindow } = require("%daeditor/components/modalWindows.nut")
let scrollHandler = ScrollHandler()
let markedStateScenes = mkWatched(persist, "markedStateScenes", {})
let editedStateScenes = mkWatched(persist, "editedStateScenes", {})
let expandedStateScenes = mkWatched(persist, "expandedStateScenes", {})
let hasChildrenStateScenes = mkWatched(persist, "hasChildrenStateScenes", {});
let filterString = mkWatched(persist, "filterString", "")
let filterImportString = mkWatched(persist, "filterImportString", "")
let filterScenesBySelectedEntities = mkWatched(persist, "filterScenesBySelectedEntities", true)
let selectionStateEntities = mkWatched(persist, "selectionStateEntities", {})
let allEntities = mkWatched(persist, "allEntities", [])
let filteredEntities = Watched([])
let {scan_folder, mkpath, file_exists} = require("dagor.fs")
let {get_arg_value_by_name} = require("dagor.system")
let datablock = require("DataBlock")
let { Point3 } = require("dagor.math")
let { isStringFloat } = require("%sqstd/string.nut")
let { fileName } = require("%sqstd/path.nut")

let sceneSortState = Watched(defaultScenesSortMode)


local sceneSortFuncCache = defaultScenesSortMode.func

const TREE_CONTROL_CONTROL_WIDTH = 20

let sceneDragData = Watched(null)

let statusAnimTrigger = { lastN = null }

let selectedEntitiesSceneIds = Computed(function() {
  local res = [[],  [],  [],  [],  []]
  local generated = false
  local saved = false
  foreach (eid, _v in selectedEntities.get()) {
    local loadType = entity_editor?.get_instance().getEntityRecordLoadType(eid)
    if (loadType != 0) {
      res[loadType].append(entity_editor?.get_instance().getEntityRecordSceneId(eid))
    }
    if (!generated || !saved) {
      local isScene = entity_editor?.get_instance().isSceneEntity(eid)
      generated = generated || (isScene == false)
      saved = saved || (isScene == true)
    }
  }
  if (generated)
    res[loadTypeConst].append(sceneGenerated.id)
  if (saved)
    res[loadTypeConst].append(sceneSaved.id)
  return res
})

function getSelectedIdsCount(selectedIds) {
  local selectedIdsCount = 0
  foreach (_i, ids in selectedIds)
    selectedIdsCount += ids.len()
  return selectedIdsCount
}

function matchSceneBySelectedEntities(scene, selectedIds) {
  return selectedIds[scene.loadType].indexof(scene.index) != null
}

function sceneToText(scene) {
  if (scene.loadType == loadTypeConst) {
    return scene.asText
  }
  local edit = editedStateScenes.get()?[scene.id] ? "> " : "| "
  local loadType = null
  if (scene.importDepth != 0) {
    if (scene.loadType != 3) {
      loadType = getSceneLoadTypeText(scene)
    }
  }
  local prettyName = getScenePrettyName(scene.loadType, scene.id)
  local strippedPath = fileName(scene.path)
  local sceneName = prettyName.len() == 0 ? strippedPath : $"{prettyName} ({strippedPath})"
  local entityCount = scene.entityCount

  return $"{edit}{scene.importDepth == 0 ? "***" : ""} {sceneName}{loadType ? $" {loadType}" : "" } - Entities: {entityCount} - ID: {scene.id}"
}

function matchSceneByText(scene, text) {
  if (text==null || text=="")
    return true
  if (sceneToText(scene).tolower().indexof(text.tolower()) != null)
    return true
  return false
}

function matchSceneByFilters(scene, selectedIds, selectedIdsCount) {
  if (selectedIdsCount > 0)
    if (matchSceneBySelectedEntities(scene, selectedIds))
      return true
  if (matchSceneByText(scene, filterString.get()))
    return true
  return false
}

let filteredScenes = Computed(function() {
  local scenes = allScenesWatcher.get()?.map(function (item, ind) {
      item.index <- ind
      return item
      }) ?? [] 
  scenes = [sceneGenerated, sceneSaved].extend(scenes)
  if (filterScenesBySelectedEntities.get()) {
    local selectedIds = selectedEntitiesSceneIds.get()
    local selectedIdsCount = getSelectedIdsCount(selectedIds)
    if (selectedIdsCount > 0)
      scenes = scenes.filter(@(scene) matchSceneBySelectedEntities(scene, selectedIds))
  }
  if (filterString.get() != "")
    scenes = scenes.filter(@(scene) matchSceneByText(scene, filterString.get()))
  if (sceneSortFuncCache != null)
    scenes.sort(sceneSortFuncCache)
  return scenes
})

let filteredScenesHierarchy = Computed(function() {
  function isInExpandedHierarchy(scene) {
    local currentScene = scene
    while (currentScene.hasParent) {
      local parentScene = sceneIdMap.get()?[currentScene.parent]
      if (!expandedStateScenes?.get()?[parentScene.id]) {
        return false;
      }
      currentScene = parentScene
    }

    return true;
  }

  local scenes = allScenesWatcher.get()?.map(function (item, ind) {
      item.index <- ind
      return item
      }) ?? [] 
  scenes = [sceneGenerated, sceneSaved].extend(scenes).filter(function (scene) {
    if (!scene?.hasParent) {
      return true
    }

    return isInExpandedHierarchy(scene)
  })

  if (filterString.get() != "")
    scenes = scenes.filter(@(scene) matchSceneByText(scene, filterString.get()))
  if (sceneSortFuncCache != null)
    scenes.sort(sceneSortFuncCache)
  return scenes
})

let filteredScenesCount = Computed(@() filteredScenes.get().len())

let filteredScenesEntityCount = Computed(function() {
  local eCount = 0
  foreach (scene in filteredScenes.get()) {
    eCount += scene.entityCount
  }
  return eCount
})

function filterEntities() {
  local entities = allEntities.get()

  if (getNumMarkedScenes() > 0) {
    local savedMarked = markedStateScenes.get()?[sceneSaved.id]
    local generatedMarked = markedStateScenes.get()?[sceneGenerated.id]
    entities = entities.filter(@(eid) matchEntityByScene(eid, savedMarked, generatedMarked))
  }

  filteredEntities.set(entities)

  entity_editor?.get_instance().unhideAll()
  entity_editor?.get_instance().hideUnmarkedEntities(filteredEntities.get())
}

let persistMarkedScenes = function(v) {
  if (v) {
    local scenes = markedScenes.get()
    foreach (sceneId, marked in v)
      scenes[sceneId] <- marked
  }
}
markedScenes.whiteListMutatorClosure(persistMarkedScenes)
markedStateScenes.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  persistMarkedScenes(v)
  markedScenes.trigger()
  filterEntities()
})
editedStateScenes.subscribe_with_nasty_disregard_of_frp_update(@(_v) filterEntities())

function calculateSceneEntityCount(saved, generated) {
  local entities = allEntities.get()
  entities = entities.filter(@(eid) matchSceneEntity(eid, saved, generated))
  return entities.len()
}

let numMarkedScenesEntityCount = Computed(function() {
  local nMrkSaved = 0
  local nMrkGenerated = 0
  local nSaved = 0
  local nGenerated = 0
  foreach (scene in filteredScenes.get()) {
    if (markedStateScenes.get()?[scene.id]) {
      if (scene.loadType == loadTypeConst) {
        if (scene.id == sceneSaved.id)
          nSaved = calculateSceneEntityCount(true, false)
        if (scene.id == sceneGenerated.id)
          nGenerated = calculateSceneEntityCount(false, true)
      } else {
        if (scene.importDepth == 0 || editedStateScenes.get()?[scene.id])
          nMrkSaved += scene.entityCount
        else
          nMrkGenerated += scene.entityCount
      }
    }
  }
  return (nSaved > 0 ? nSaved : nMrkSaved) + (nGenerated > 0 ? nGenerated : nMrkGenerated)
})

function markScene(cb) {
  markedStateScenes.mutate(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}




let markAllFiltered = function() {
  local selectedIds = selectedEntitiesSceneIds.get()
  local selectedIdsCount = getSelectedIdsCount(selectedIds)
  markScene(@(scene, _cur) matchSceneByFilters(scene, selectedIds, selectedIdsCount))
}

let markSceneNone = @() markScene(@(_scene, _cur) false)


let markScenesInvert = function() {
  local selectedIds = selectedEntitiesSceneIds.get()
  local selectedIdsCount = getSelectedIdsCount(selectedIds)
  markScene(@(scene, cur) matchSceneByFilters(scene, selectedIds, selectedIdsCount) ? !cur : false)
}

let toggleEditing = function() {
  editedStateScenes.mutate(function(value) {
    foreach (sceneId, edited in value) {
      if (markedStateScenes.get()?[sceneId]) {
        local loadType = sceneIdMap.get()?[sceneId].loadType
        if (entity_editor?.get_instance().isChildScene(loadType, sceneId)) {
          entity_editor?.get_instance().setChildSceneEditable(loadType, sceneId, !edited)
          value[sceneId] = !edited
        }
      }
    }
  })
}

function scrollScenesBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("scene" in desc) && markedStateScenes.get()?[desc.scene.id]
  }, 2, false, true)
}

function scnTxt(count) { return count==1 ? "scene" : "scenes" }
function entTxt(count) { return count==1 ?  "entity" : "entities" }
function statusText(count, textFunc) { return format("%d %s", count, textFunc(count)) }

function statusLineScenes() {
  let sMrk = getNumMarkedScenes()
  let eMrk = numMarkedScenesEntityCount.get()
  let eRec = filteredScenesEntityCount.get()

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != sMrk)
    anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = sMrk

  return {
    watch = [numMarkedScenesEntityCount, filteredScenesCount, filteredScenesEntityCount, markedStateScenes, selectedEntities, editedStateScenes]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        size = FLEX_H
        text = format(" %s, with %s, marked", statusText(sMrk, scnTxt), statusText(eMrk, entTxt))
        animations = [
          { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=statusAnimTrigger }
        ]
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = FLEX_H
        text = format(" %s, with %s, listed", statusText(filteredScenesCount.get(), scnTxt), statusText(eRec, entTxt))
        color = Color(170,170,170)
      }
    ]
  }
}

let filter = nameFilter(filterString, {
  placeholder = "Filter by load-type/path/entities"

  function onChange(text) {
    filterString.set(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    filterString.set("")
    set_kb_focus(null)
  }
})

function getEmptySpaceAsOffset(scene) {
  if (filterScenesBySelectedEntities.get()) {
    return {}
  }

  local offset = 0;
  local currentScene = scene
  if (!currentScene?.hasParent) {
    return {}
  }

  while (currentScene?.hasParent) {
    ++offset
    currentScene = sceneIdMap.get()?[currentScene.parent]
  }

  return {
    size = [hdpx(offset * TREE_CONTROL_CONTROL_WIDTH), flex() ]
  }
}

function getSelectedScenesIndicies(scenes) {
  return scenes.get()?.filter(@(marked, _sceneId) marked).keys()
}

function initScenesList() {
  updateAllScenes()
  hasChildrenStateScenes.set({})

  foreach (scene in getAllScenes()) {
    local isMarked = markedScenes.get()?[scene.id] ?? false
    local isEdited = editedStateScenes.get()?[scene.id] ?? false
    local isExpanded = expandedStateScenes.get()?[scene.id] ?? false
    local hasChildren = hasChildrenStateScenes.get()?[scene.id] ?? false

    markedStateScenes.get()[scene.id] <- isMarked
    editedStateScenes.get()[scene.id] <- isEdited
    expandedStateScenes.get()[scene.id] <- isExpanded
    hasChildrenStateScenes.get()[scene.id] <- hasChildren

    if (scene.hasParent) {
      local parentScene = sceneIdMap.get()?[scene.parent]
      hasChildrenStateScenes.get()[parentScene.id] <- true
    }
  }

  markedStateScenes.set(markedStateScenes.get().filter(@(_val, key) key in sceneIdMap.get()))
  editedStateScenes.set(editedStateScenes.get().filter(@(_val, key) key in sceneIdMap.get()))
  expandedStateScenes.set(expandedStateScenes.get().filter(@(_val, key) key in sceneIdMap.get()))
  hasChildrenStateScenes.set(hasChildrenStateScenes.get().filter(@(_val, key) key in sceneIdMap.get()))

  markedStateScenes.trigger()
}

sceneListUpdateTrigger.subscribe_with_nasty_disregard_of_frp_update(@(_v) initScenesList())

let dragDestScene = Watched(null)

function listSceneRow(scene, idx) {
  return watchElemState(function(sf) {
    let isMarked = markedStateScenes.get()?[scene.id]
    let textColor = isMarked ? colors.TextDefault : colors.TextDarker
    let color = isMarked ? colors.Active
    : sf & S_TOP_HOVER ? colors.GridRowHover
    : colors.GridBg[idx % colors.GridBg.len()]

    function getTreeControl() {
      return !filterScenesBySelectedEntities.get() && hasChildrenStateScenes.get()?[scene.id] ?
        {
          rendObj = ROBJ_SOLID
          behavior = Behaviors.Button
          color = Color(224, 224, 224)
          size = static [ hdpx(14), hdpx(14) ]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = {
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            rendObj = ROBJ_TEXT
            text = expandedStateScenes.get()[scene.id] ? "-" : "+"
            color = Color(0, 0, 0)
          }

          onClick = function () {
            expandedStateScenes.mutate(function(value) {
              value[scene.id] <- !value?[scene.id]
            })
          }
        }
        : {}
    }

    let canBeDropped = Computed(function () {
      if (!sceneDragData.get()) {
        return false
      }


      if (scene.loadType != 3 || (scene.importDepth != 0 && !entity_editor?.get_instance().isChildScene(3, scene.id))) {
        return false
      }

      function isInHierarchy(sceneId) {
        local destScene = scene
        while (destScene?.hasParent) {
          if (destScene.parent == sceneId) {
            return true
          }

          destScene = sceneIdMap?.get()[destScene.parent]
        }

        return false
      }

      foreach (id in sceneDragData.get()) {
        if (isInHierarchy(id)) {
          return false;
        }
      }

      return true
    })

    let elemColor = Computed(function () {
      return (sf & S_DRAG) ? Color(255,255,0) : ( sceneDragData.get() && !canBeDropped.get() ? Color(255,0,0) : Color(255,255,255) )
    })

    function isDraggable() {
      return scene.loadType == 3 && scene.importDepth != 0 && entity_editor?.get_instance().isChildScene(3, scene.id)
    }

    return {
      rendObj = ROBJ_BOX
      size = FLEX_H
      fillColor = color
      borderWidth = (dragDestScene.get() && dragDestScene.get().id == scene.id) || (sf & S_DRAG) ? 1 : 0
      borderColor = elemColor.get()
      scene
      behavior = (isDraggable() || sceneDragData.get()) && !filterScenesBySelectedEntities.get() ? Behaviors.DragAndDrop : Behaviors.Button
      flow = FLOW_HORIZONTAL

      watch = [expandedStateScenes, sceneDragData, dragDestScene]
      canDrop = function(_data) {
        dragDestScene.set(scene)
        return canBeDropped.get()
      }
      onDrop = function(_data) {
        if (dragDestScene.get() && sceneDragData.get()) {
          foreach (id in sceneDragData.get()) {
            entity_editor?.get_instance().setSceneNewParent(id, dragDestScene.get().id)
          }
          expandedStateScenes?.mutate(function(value) {
            value[dragDestScene.get().id] = true
          })
          initScenesList()
        }
      }
      dropData = scene
      onDragMode = function(on, _val) {
        if (markedStateScenes?.get()[scene.id] == true) {
          local selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)?.filter(function(value) {
            return sceneIdMap.get()?[value].loadType == 3
          })
          sceneDragData.set(on ? selectedSceneIds : null)
        }
        else {
          sceneDragData.set(on ? [scene.id] : null)
        }
        if (!on) {
          dragDestScene.set(null)
        }
      }

      function onClick(evt) {
        if (evt.shiftKey) {
          local selCount = 0
          foreach (_k, v in markedStateScenes.get()) {
            if (v)
              ++selCount
          }
          if (selCount > 0) {
            local idx1 = -1
            local idx2 = -1
            foreach (i, filteredScene in filteredScenes.get()) {
              if (scene == filteredScene) {
                idx1 = i
                idx2 = i
              }
            }
            foreach (i, filteredScene in filteredScenes.get()) {
              if (markedStateScenes.get()?[filteredScene.id]) {
                if (idx1 > i)
                  idx1 = i
                if (idx2 < i)
                  idx2 = i
              }
            }
            if (idx1 >= 0 && idx2 >= 0) {
              if (idx1 > idx2) {
                let tmp = idx1
                idx1 = idx2
                idx2 = tmp
              }
              markedStateScenes.mutate(function(value) {
                for (local i = idx1; i <= idx2; i++) {
                  let filteredScene = filteredScenes.get()[i]
                  value[filteredScene.id] <- !evt.ctrlKey
                }
              })
            }
          }
        }
        else if (evt.ctrlKey) {
          markedStateScenes.mutate(function(value) {
            value[scene.id] <- !value?[scene.id]
          })
        }
        else {
          local wasMarked = markedStateScenes.get()?[scene.id]
          markSceneNone()
          if (!wasMarked) {
            markedStateScenes.mutate(function(value) {
              value[scene.id] <- true
            })
          }
        }
      }

      children = [
        {
          flow = FLOW_HORIZONTAL
          margin = fsh(0.5)
          children = [
            getEmptySpaceAsOffset(scene)
            {
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              flow = FLOW_HORIZONTAL
              size = static [ hdpx(TREE_CONTROL_CONTROL_WIDTH), flex() ]
              children = getTreeControl()
            }
            {
              rendObj = ROBJ_TEXT
              text = sceneToText(scene)
              color = textColor
            }
          ]
        }
      ]
    }
  })
}

function listRowMoreLeft(num, idx) {
  return watchElemState(function(sf) {
    let color = (sf & S_TOP_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    return {
      rendObj = ROBJ_SOLID
      size = FLEX_H
      color
      children = {
        rendObj = ROBJ_TEXT
        text = $"{num} more ..."
        color = colors.TextReadOnly
        margin = fsh(0.5)
      }
    }
  })
}

sceneSortState.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  sceneSortFuncCache = v?.func
  selectedEntities.trigger()
  markedStateScenes.trigger()
  initScenesList()
})

de4workMode.subscribe(@(_) gui_scene.resetTimeout(0.1, initScenesList))

function initEntitiesList() {
  let entities = entity_editor?.get_instance().getEntities("") ?? []
  foreach (eid in entities) {
    let isSelected = selectedEntities.get()?[eid] ?? false
    selectionStateEntities.get()[eid] <- isSelected
  }
  allEntities.set(entities)
  selectionStateEntities.trigger()
}

function initLists() {
  initScenesList();
  initEntitiesList();
}

function mkCheckBox(value, onClick) {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let hoverFlag = Computed(@() stateFlags.get() & S_HOVER)

  return function () {
    local mark = null
    if (value.get()) {
      mark = {
        rendObj = ROBJ_SOLID
        color = (hoverFlag.get() != 0) ? colors.Hover : colors.Interactive
        group
        size = [pw(50), ph(50)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
      }
    }

    return {
      flow = FLOW_HORIZONTAL
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER

      watch = [value]

      children = [
        {
          size = [fontH(80), fontH(80)]
          rendObj = ROBJ_SOLID
          color = colors.ControlBg

          behavior = Behaviors.Button
          group

          children = mark

          onElemState = @(sf) stateFlags.set(sf)

          onClick
        }
      ]
    }
  }
}

function sceneFilterCheckbox() {
  return @() {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    halign = ALIGN_LEFT
    valign = ALIGN_CENTER

    watch = [filterScenesBySelectedEntities]

    children = [
      mkCheckBox(filterScenesBySelectedEntities, function() {
        filterScenesBySelectedEntities.set(!filterScenesBySelectedEntities.get())
      })
      {
        flow = FLOW_HORIZONTAL
        rendObj = ROBJ_TEXT
        halign = ALIGN_LEFT
        text = "Pre-filter based on selected entities"
        color = colors.TextDefault
        margin = fsh(0.5)
      }
    ]
  }
}

const selectSceneUID = "select_scene_modal_window"

let gamebase = get_arg_value_by_name("gamebase")
let root     = gamebase != null ? $"{gamebase}/" : ""
let selectedImport = Watched("")

let addImportFilter = nameFilter(filterImportString, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterImportString.set(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    filterImportString.set("")
    set_kb_focus(null)
  }
})

function listImportSceneRow(scene, index) {
  return watchElemState(function(sf) {
    return {
      rendObj = ROBJ_SOLID
      size = FLEX_H
      color = selectedImport.get() == scene ? colors.Active : sf & S_TOP_HOVER ? colors.GridRowHover : colors.GridBg[index % colors.GridBg.len()]
      scene
      behavior = Behaviors.Button
      watch = selectedImport

      function onClick() {
        selectedImport.set(scene)
      }

      children = {
        rendObj = ROBJ_TEXT
        text = scene
        color = colors.TextDefault
        margin = fsh(0.5)
      }
    }
  })
}

let doImportScene = function(scenePath) {
  let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
  if (selectedSceneIds?.len() == 1) {
    entity_editor?.get_instance().addImportScene(selectedSceneIds[0], scenePath)
    expandedStateScenes?.mutate(function(value) {
      value[selectedSceneIds[0]] = true
    })
    markedScenes.trigger()
    initScenesList()
  }
}

let importScene = function() {
  let close = function() {
    removeModalWindow(selectSceneUID)
    selectedImport.set("")
  }

  let isScenePathValid = Computed(@() selectedImport.get()!=null && selectedImport.get()!="")

  let scenes = scan_folder({ root = $"{root}gamedata/scenes", vromfs = true, realfs = true, recursive = true, files_suffix = "*.blk" })
    .map(function (f) {
      return f.replace($"{root}", "")
    })

  let filteredImports = Computed(function() {
    local scenesCopy = scenes.map(@(scene) scene)
    if (filterImportString.get() != "")
      scenesCopy = scenesCopy.filter(function(scene) {
        local text = filterImportString.get()
        if (text==null || text=="")
          return true
        if (scene.tolower().indexof(text.tolower()) != null)
          return true
        return false
    })
    return scenesCopy
  })

  function listImportContent() {
    let sRows = filteredImports.get().map(@(scene, index) listImportSceneRow(scene, index))

    return {
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = sRows
      behavior = Behaviors.Button
      watch = filteredImports
    }
  }

  addModalWindow({
    key = selectSceneUID
    children =
    {
      behavior = Behaviors.Button
      gap = fsh(0.5)
      flow = FLOW_VERTICAL
      rendObj = ROBJ_SOLID
      size = static [hdpx(700), hdpx(768)]
      color = Color(20,20,20,255)
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      padding = hdpx(10)
      children = [
        {
          children = txt("Select a scene to import")
        }
        {
          size = FLEX_H
          flow = FLOW_HORIZONTAL
          children = addImportFilter
        }
        {
          size = flex()
          children = makeVertScroll(listImportContent)
        }
        hflow(
          textButton("Cancel", close, {hotkeys=[["Esc"]]})
            @() {
              watch = isScenePathValid
              children = isScenePathValid.get() ? textButton("Add scene", function() {
                doImportScene(selectedImport.get())
                close()
              }) : null
            }
        )
      ]
    }
  })
}

const importNewSceneUID = "import_new_scene_modal_window"
const baseScenePath = "gamedata/scenes/"

let doImportNewScene = function(sceneName) {
  let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
  if (selectedSceneIds?.len() == 1) {
    let path = $"{baseScenePath}{sceneName}.blk"
    mkpath($"%gameBase/{path}")
    let data = datablock()
    data.saveToTextFile($"%gameBase/{path}");
    entity_editor?.get_instance().addImportScene(selectedSceneIds[0], path)
    expandedStateScenes?.mutate(function(value) {
      value[selectedSceneIds[0]] = true
    })
    initLists()
  }
}

function importNewScene() {
  let close = @() removeModalWindow(importNewSceneUID)
  let newSceneName = Watched("")
  let isSceneValid = Computed(@() newSceneName.get()!=null && newSceneName.get()!="" && !file_exists($"%gameBase/{baseScenePath}{newSceneName.get()}.blk"))

  addModalWindow({
    key = importNewSceneUID
    children =
    {
      behavior = Behaviors.Button
      gap = fsh(0.5)
      flow = FLOW_VERTICAL
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      color = Color(20,20,20,255)
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      padding = hdpx(10)
      children = [
        {
          children = txt("Enter new scene name")
        }
        {
          size = FLEX_H
          children = textInput(newSceneName)
        }
        hflow(
          textButton("Cancel", close, {hotkeys=[["Esc"]]})
            @() {
              watch = isSceneValid
              children = textButton("Create and add", function() {
                doImportNewScene(newSceneName.get())
                close()
              }, { off = !isSceneValid.get(), disabled = Computed(@() !isSceneValid.get()) })
            }
        )
      ]
    }
  })
}

function createTransferEntitiesToSceneButton() {
  function makeSceneEditable(sceneId) {
    editedStateScenes.mutate(function(value) {
      entity_editor?.get_instance().setChildSceneEditable(sceneIdMap.get()?[sceneId].loadType, sceneId, true)
      value[sceneId] = true
    })
  }

  function transferEntities() {
    if (getNumMarkedScenes() == 1) {
      let sceneId = getSelectedScenesIndicies(markedStateScenes)?[0]

      
      makeSceneEditable(sceneId)

      
      foreach (id, _ in selectedEntities.get()) {
        local loadTypeVal = entity_editor?.get_instance().getEntityRecordLoadType(id) ?? -1
        local eSceneId = entity_editor?.get_instance().getEntityRecordSceneId(id) ?? -1
        if (eSceneId != -1 && loadTypeVal == 3) {
          makeSceneEditable(eSceneId)
        }
      }

      entity_editor?.get_instance().transferEntitiesToScene(selectedEntities.get().keys(), sceneId)
      initLists()
    }
  }

  function isImportSelected() {
    if (getNumMarkedScenes() != 1) {
      return false;
    }

    return sceneIdMap.get()?[getSelectedScenesIndicies(markedStateScenes)?[0]].loadType == 3
  }

  let isSelectedEntitesValid = Computed(function () {
    if (selectedEntities.get().len() == 0) {
      return false
    }

    foreach (id, _ in selectedEntities.get()) {
      if (entity_editor?.get_instance().isSceneEntity(id) && entity_editor?.get_instance().getEntityRecordLoadType(id) != 3) {
        return false
      }
    }

    return true
  })

  let canTransferEntities = Computed(@() isSelectedEntitesValid.get() && isImportSelected())
  return textButton("Transfer entities", transferEntities, { off = !canTransferEntities.get(), disabled = Computed(@() !canTransferEntities.get() )})
}

function selectScenes() {
    entity_editor?.get_instance().selectScenes(getSelectedScenesIndicies(markedStateScenes).map(@(val) val))
  }

function createSelectButton() {
  let canSelectScenes = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds == null || selectedSceneIds.len() == 0) {
      return false
    }

    foreach (sceneId in selectedSceneIds) {
      if (sceneIdMap.get()?[sceneId].loadType != 3) {
        return false
      }
    }
    return true
  })

  return textButton("Select", selectScenes, { off = !canSelectScenes.get(), disabled = Computed(@() !canSelectScenes.get() )})
}

let canAddImport = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds?.len() != 1) {
      return false
    }

    local scene = sceneIdMap?.get()[selectedSceneIds[0]]
    if (scene?.loadType != 3) {
      return false
    }

    return scene.importDepth == 0 || entity_editor?.get_instance().isChildScene(3, scene.id)
  })

function createImportExistingSceneButton() {
  return textButton("Import existing", importScene, { off = !canAddImport.get(), disabled = Computed(@() !canAddImport.get() )})
}

function createImportNewSceneButton() {
  return textButton("Import new", importNewScene, { off = !canAddImport.get(), disabled = Computed(@() !canAddImport.get() )})
}

function createRemoveScenesButton() {
  let canRemoveScenes = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds == null || selectedSceneIds.len() == 0) {
      return false
    }

    foreach (id in selectedSceneIds) {
      local scene = sceneIdMap?.get()[id]
      if (scene == null || scene.loadType != 3 || scene.importDepth == 0 ||
        (scene.importDepth != 0 && !entity_editor?.get_instance().isChildScene(3, scene.id))) {
        return false
      }
    }

    return true
  })

  return textButton("Remove", function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds) {
      entity_editor?.get_instance().removeScenes(selectedSceneIds)
      initLists()
    }
  }, { off = !canRemoveScenes.get(), disabled = Computed(@() !canRemoveScenes.get() )})
}

const setSceneNameUID = "set_scene_name_modal_window"

function createSetNameButton() {
  let canSetName = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds == null || selectedSceneIds.len() != 1) {
      return false
    }

    return sceneIdMap.get()?[selectedSceneIds[0]].loadType == 3;
  })

  function getSelectedPrettyName() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds?.len() == 1) {
      return entity_editor?.get_instance().getScenePrettyName(selectedSceneIds[0])
    }
    return ""
  }

  function setName() {
    let sceneName = Watched(getSelectedPrettyName())

    let close = function() {
      removeModalWindow(setSceneNameUID)
    }

    function doSetSceneName() {
      local confirmationUID = "clear_scene_name_modal_window"

      function applySceneName() {
        let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
        if (selectedSceneIds != null && selectedSceneIds.len()  == 1) {
          entity_editor?.get_instance().setScenePrettyName(selectedSceneIds[0], sceneName.get())
          initScenesList()
        }
      }

      if (sceneName.get().len() == 0) {
        addModalWindow({
          key = confirmationUID
          children = vflow(
            Button
            Gap(fsh(0.5))
            RendObj(ROBJ_SOLID)
            Padding(hdpx(10))
            Colr(20,20,20,255)
            Size(hdpx(330), SIZE_TO_CONTENT)
            vflow(
              HCenter
              txt("Are you sure you want to clear scene name?"))
            hflow(
              HCenter
              textButton("Cancel", @() removeModalWindow(confirmationUID), {hotkeys=[["Esc"]]})
              textButton("Ok", function () {
                applySceneName()
                removeModalWindow(confirmationUID)
              }, {hotkeys=[["Enter"]]})
            )
          )
        })
      }
      else {
        applySceneName()
      }
    }

    addModalWindow({
      key = setSceneNameUID
      children = vflow(
        Button
        Gap(fsh(0.5))
        RendObj(ROBJ_SOLID)
        Padding(hdpx(10))
        Colr(20,20,20,255)
        vflow(Size(flex(), SIZE_TO_CONTENT), txt("Enter scene name:"))
        textInput(sceneName)
        hflow(
          textButton("Cancel", close, {hotkeys=[["Esc"]]})
            @() {
              children = textButton("Apply", function() {
                doSetSceneName()
                close()
              })
            }
        )
      )
    })
  }

  return textButton("Set name", setName, { off = !canSetName.get(), disabled = Computed(@() !canSetName.get() )})
}

let canChangeOrder = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds?.len() != 1) {
      return false
    }

    local scene = sceneIdMap?.get()[selectedSceneIds[0]]
    if (scene?.loadType != 3) {
      return false
    }

    return entity_editor?.get_instance().isChildScene(3, scene.id)
  })


function createOrderUpButton() {
  return textButton("Order up", function () {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    let sceneId = selectedSceneIds?[0]
    let childOrder = entity_editor?.get_instance().getSceneOrder(3, sceneId)
    if (childOrder != null && childOrder != 0) {
      entity_editor?.get_instance().setSceneOrder(sceneId, childOrder - 1)
      initLists()
    }
  }, { off = !canChangeOrder.get(), disabled = Computed(@() !canChangeOrder.get() )})
}

function createOrderDownButton() {
  return textButton("Order down", function () {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    let sceneId = selectedSceneIds?[0]
    let childOrder = entity_editor?.get_instance().getSceneOrder(3, sceneId)
    if (childOrder != null) {
      entity_editor?.get_instance().setSceneOrder(sceneId, childOrder + 1)
      initLists()
    }
  }, { off = !canChangeOrder.get(), disabled = Computed(@() !canChangeOrder.get() )})
}

function createScenePropertiesControl() {
  let sceneIndex = Computed(function() {
    let selectedSceneIds = markedStateScenes.get()?.filter(@(marked, _sceneId) marked).keys()
    if (selectedSceneIds == null || selectedSceneIds.len() != 1) {
      return -1
    }
    let sceneId = selectedSceneIds[0]
    if (sceneIdMap.get()?[sceneId].loadType != 3) {
      return -1
    }

    return sceneId;
  })

  function getIsTransformable() {
    return sceneIndex.get() != -1 ? entity_editor?.get_instance().isSceneTransformable(sceneIndex.get()) : false
  }

  let isTransformable = Watched(getIsTransformable())
  let pivot = entity_editor?.get_instance().getScenePivot(sceneIndex.get())
  let pivotX = Watched(pivot ? pivot.x : "")
  let pivotY = Watched(pivot ? pivot.y : "")
  let pivotZ = Watched(pivot ? pivot.z : "")

  function onPivotXChanged(val) {
    if (isStringFloat(val)) {
      entity_editor?.get_instance().setScenePivot(sceneIndex.get(),
        Point3(val.tofloat(), pivotY.get().tofloat(), pivotZ.get().tofloat()))
      selectScenes();
    }
  }

  function onPivotYChanged(val) {
    if (isStringFloat(val)) {
      entity_editor?.get_instance().setScenePivot(sceneIndex.get(),
        Point3(pivotX.get().tofloat(), val.tofloat(), pivotZ.get().tofloat()))
      selectScenes();
    }
  }

  function onPivotZChanged(val) {
    if (isStringFloat(val)) {
      entity_editor?.get_instance().setScenePivot(sceneIndex.get(),
        Point3(pivotX.get().tofloat(), pivotY.get().tofloat(), val.tofloat()))
      selectScenes();
    }
  }

  function getPropertiesControls() {
    return [
      {
        flow = FLOW_HORIZONTAL
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        children = [
          {
              rendObj = ROBJ_TEXT
              text = "Transformable"
              color = colors.TextDefault
              margin = fsh(0.5)
          }
          mkCheckBox(isTransformable, function() {
            if (sceneIndex.get() != -1) {
              let currVal = isTransformable.get()
              entity_editor?.get_instance().setSceneTransformable(sceneIndex.get(), !currVal)
              isTransformable.set(!currVal)
            }
          })
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        children = [
          {
            rendObj = ROBJ_TEXT
            text = "Pivot"
            color = colors.TextDefault
            margin = fsh(0.5)
          }
          {
            flow = FLOW_HORIZONTAL
            halign = ALIGN_CENTER
            size = static [ hdpx(300), SIZE_TO_CONTENT ]
            children = [
              textInput(pivotX, { textmargin = [sh(0), sh(0)], valignText = ALIGN_CENTER, onChange = onPivotXChanged })
              textInput(pivotY, { textmargin = [sh(0), sh(0)], valignText = ALIGN_CENTER, onChange = onPivotYChanged })
              textInput(pivotZ, { textmargin = [sh(0), sh(0)], valignText = ALIGN_CENTER, onChange = onPivotZChanged })
            ]
          }
        ]
      }
    ]
  }

  return @() {
    flow = FLOW_HORIZONTAL
    halign = ALIGN_LEFT
    valign = ALIGN_CENTER
    watch = [sceneIndex]
    children = sceneIndex.get() != -1 ? getPropertiesControls() : []
  }
}

function mkScenesList() {

  function listSceneContent() {
    const maxVisibleItems = 250
    local sRows;

    if (filterScenesBySelectedEntities.get()) {
      sRows = filteredScenes.get().slice(0, maxVisibleItems).map(@(scene, idx) listSceneRow(scene, idx))
      if (sRows.len() < filteredScenes.get().len())
        sRows.append(listRowMoreLeft(filteredScenes.get().len() - sRows.len(), sRows.len()))
    }
    else {
      sRows = filteredScenesHierarchy.get().slice(0, maxVisibleItems).map(@(scene, idx) listSceneRow(scene, idx))
      if (sRows.len() < filteredScenesHierarchy.get().len())
        sRows.append(listRowMoreLeft(filteredScenesHierarchy.get().len() - sRows.len(), sRows.len()))
    }

    return {
      watch = [selectedEntities, markedStateScenes, filteredScenes, filteredScenesHierarchy, editedStateScenes, filterScenesBySelectedEntities]
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = sRows
      behavior = Behaviors.Button
    }
  }

  let scrollListScenes = makeVertScroll(listSceneContent, {
    scrollHandler
    rootBase = {
      size = flex()
      function onAttach() {
        scrollScenesBySelection()
      }
    }
  })

  return  @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = [allScenesWatcher, filteredScenes, markedStateScenes, allEntities, filteredEntities, selectionStateEntities, selectedEntities, sceneListUpdateTrigger]
    size = flex()
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        children = [
          mkSceneSortModeButton(sceneSortState)
          const { size = [sw(0.2), SIZE_TO_CONTENT] }
          filter
          const { size = [fsh(0.2), 0] }
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        children = sceneFilterCheckbox()
      }
      {
        size = flex()
        children = scrollListScenes
      }
      statusLineScenes
      createScenePropertiesControl()
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        halign = ALIGN_CENTER
        children = [
          textButton("All filtered", markAllFiltered)
          textButton("None", markSceneNone)
          textButton("Invert", markScenesInvert)
          textButton("Toggle editing", toggleEditing)
          createOrderUpButton()
          createOrderDownButton()
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        halign = ALIGN_CENTER
        children = [
          createImportExistingSceneButton()
          createImportNewSceneButton()
          createRemoveScenesButton()
          createSetNameButton()
          createSelectButton()
          createTransferEntitiesToSceneButton()
        ]
      }
    ]
  }
}

return {
  id = LoadedScenesWndId
  onAttach = initLists
  mkContent = mkScenesList
  saveState=true
}
