from "string" import format
from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *

let entity_editor = require_optional("entity_editor")
let { LoadedScenesWndId, selectedEntities, markedScenes, de4workMode, allScenesWatcher,
  getAllScenes, updateAllScenes, sceneIdMap, sceneListUpdateTrigger,
  addEntityCreatedCallback, addEntityRemovedCallback } = require("state.nut")
let { colors } = require("components/style.nut")
let textButton = require("components/textButton.nut")
let nameFilter = require("components/nameFilter.nut")
let mkCheckBox = require("components/mkCheckBox.nut")
let { makeVertScroll } = require("%daeditor/components/scrollbar.nut")
let textInput = require("%daeditor/components/textInput.nut")
let { getSceneLoadTypeText, loadTypeConst, sceneGenerated, sceneSaved, getNumMarkedScenes, matchSceneEntity,
  getScenePrettyName, canSceneBeModified } = require("%daeditor/daeditor_es.nut")
let { defaultScenesSortMode, mkSceneSortModeButton } = require("components/mkSortSceneModeButton.nut")
let { addModalWindow, removeModalWindow } = require("%daeditor/components/modalWindows.nut")
let {scan_folder, mkpath, file_exists} = require("dagor.fs")
let {get_arg_value_by_name} = require("dagor.system")
let datablock = require("DataBlock")
let { Point3 } = require("dagor.math")
let { isStringFloat } = require("%sqstd/string.nut")
let { fileName } = require("%sqstd/path.nut")
let ecs = require("%sqstd/ecs.nut")

const TREE_CONTROL_CONTROL_WIDTH = 20
const DROP_BORDER_SIZE = 0.2
const TREE_CONNECTIONS_COLOR = Color(255, 255, 255)
const MAX_FREE_ENTITIES = 100

let filterSelectedEntities = Watched(false)
let showEntities = mkWatched(persist, "showEntities", true)
let itemDragData = Watched(null)
let dragDestData = Watched(null)
let dragDropPositionData = Watched(null)
let markedStateScenes = mkWatched(persist, "markedStateScenes", {})
let expandedStateScenes = mkWatched(persist, "expandedStateScenes", {})
let filterString = mkWatched(persist, "filterString", "")
let filterImportString = mkWatched(persist, "filterImportString", "")
let selectionStateEntities = mkWatched(persist, "selectionStateEntities", {})
let allEntities = mkWatched(persist, "allEntities", {})
let scrollHandler = ScrollHandler()
let sceneSortState = Watched(defaultScenesSortMode)

let statusAnimTrigger = { lastN = null }


local sceneSortFuncCache = defaultScenesSortMode.func

function sceneToText(scene) {
  if (scene.loadType == loadTypeConst) {
    return scene.asText
  }

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

  return $"{scene.importDepth == 0 ? "***" : ""} {sceneName}{loadType ? $" {loadType}" : "" } - Entities: {entityCount} - ID: {scene.id}"
}

let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

function entityToTxt(eid) {
  local tplName = ecs.g_entity_mgr.getEntityTemplateName(eid) ?? ""
  let name = removeSelectedByEditorTemplate(tplName)
  return $"{eid} - {name}"
}

let isFilteringEnabled = Computed(function (){
  return (filterSelectedEntities?.get() ?? false) || (filterString?.get() != null && filterString.get().len() != 0)
})

let fakeScene = {
  loadType = 3
  entityCount = 0
  path = "Entities without scene"
  importDepth = 1
  parent = ecs.INVALID_SCENE_ID
  hasParent = false
  imports = 0
  id = ecs.INVALID_SCENE_ID
  hasChildren = false
}

function getScene(id) {
  return id != ecs.INVALID_SCENE_ID ? sceneIdMap?.get()[id] : fakeScene
}

let filteredItems = Computed(function() {
  local scenes = allScenesWatcher.get()?.map(function (item, ind) {
    item.index <- ind
    return item
    }) ?? [] 
  local items = []

  local rootScenes = scenes.filter(function (scene) {
    return !scene.hasParent
  })

  if (sceneSortFuncCache != null)
    rootScenes.sort(sceneSortFuncCache)

  function filterItem(item) {
    if (item?.entity != null && !showEntities.get()) {
      return false
    }

    if (filterSelectedEntities?.get()) {
      if (item?.entity == null) {
        return false
      }

      if (!selectedEntities?.get()[item.entity.id]) {
        return false
      }
    }

    let filterStr = filterString.get()
    if (filterStr != null && filterStr.len() != 0) {
      let itemStr = item?.scene != null ? sceneToText(item.scene) : entityToTxt(item.entity.id)

      return itemStr.tolower().indexof(filterStr.tolower()) != null
    }
    return true
  }

  function createFakeSceneItems(order) {
    local sceneItem = {}
    let entities = allEntities?.get()[ecs.INVALID_SCENE_ID] ?? []

    sceneItem.scene <- fakeScene
    sceneItem.order <- order
    sceneItem.scene.entityCount = entities.len()
    sceneItem.scene.hasChildren = false
    sceneItem.depth <- 0

    let fakeItems = []
    local isAnythingFilteredIn = filterItem(sceneItem)

    foreach (eid in entities) {
      if (fakeItems.len() >= MAX_FREE_ENTITIES) {
        local textItem = {}
        textItem.text <- "More entities ...";
        textItem.parentSceneId <- ecs.INVALID_SCENE_ID
        textItem.depth <- 1

        fakeItems.append(textItem)
        break
      }

      local entityItem = {}
      entityItem.entity <- {}
      entityItem.entity.id <- eid
      entityItem.entity.parentSceneId <- ecs.INVALID_SCENE_ID
      entityItem.order <- fakeItems.len()
      entityItem.depth <- 1

      let isExpanded = expandedStateScenes?.get()?[ecs.INVALID_SCENE_ID] ?? false

      if (filterItem(entityItem)) {
        isAnythingFilteredIn = true
        sceneItem.scene.hasChildren = true
        if (isExpanded) {
          fakeItems.append(entityItem)
        }
      }
    }

    if (isAnythingFilteredIn) {
      fakeItems.insert(0, sceneItem)
    }

    return fakeItems
  }

  function processScene(scene, order, isParentExpanded, depth) {
    local sceneItem = {}
    sceneItem.scene <- scene
    sceneItem.order <- order
    sceneItem.scene.hasChildren <- false
    sceneItem.depth <- depth

    local insertionPos = items.len()
    local isAnythingFilteredIn = filterItem(sceneItem)
    let isExpanded = isParentExpanded && (expandedStateScenes?.get()?[scene.id] ?? false)

    local entries = entity_editor?.get_instance().getSceneOrderedEntries(scene.loadType, scene.id) ?? []
    local i = 0
    foreach (entry in entries) {
      if (entry.isEntity) {
        local entityItem = {}
        entityItem.entity <- {}
        entityItem.entity.id <- entry.eid
        entityItem.entity.parentSceneId <- scene.id
        entityItem.order <- i
        entityItem.depth <- depth + 1

        if (filterItem(entityItem)) {
          isAnythingFilteredIn = true
          sceneItem.scene.hasChildren = true

          if (isExpanded) {
            items.append(entityItem)
            ++i
          }
        }
      }
      else {
        local filteredIn = processScene(getScene(entry.sid), i, isExpanded, depth + 1)
        if (filteredIn) {
          ++i
          isAnythingFilteredIn = true
          sceneItem.scene.hasChildren = true
        }
      }
    }

    if (isAnythingFilteredIn && isParentExpanded) {
      items.insert(insertionPos, sceneItem)
    }

    return isAnythingFilteredIn
  }

  local i = 0
  foreach (scene in rootScenes) {
    if (processScene(scene, i, true, 0)) {
      ++i
    }
  }

  items.extend(createFakeSceneItems(i))

  return items
})

let filteredScenesCount = Computed(@() filteredItems.get().filter(@(item) item?.scene != null && item.scene.id != ecs.INVALID_SCENE_ID).len())

let filteredScenesEntityCount = Computed(function() {
  local eCount = 0
  foreach (item in filteredItems.get()) {
    eCount += item?.scene.entityCount ?? 0
  }
  return eCount
})

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
})

function calculateSceneEntityCount(saved, generated) {
  local entities = allEntities.get()
  entities = entities.filter(@(eid) matchSceneEntity(eid, saved, generated))
  return entities.len()
}

let numMarkedScenesEntityCount = Computed(function() {
  local nSaved = 0
  local nGenerated = 0
  foreach (item in filteredItems.get()) {
    if (item?.scene) {
      local scene = item.scene
      if (markedStateScenes.get()?[scene.id]) {
        if (scene.loadType == loadTypeConst) {
          if (scene.id == sceneSaved.id)
            nSaved = calculateSceneEntityCount(true, false)
          if (scene.id == sceneGenerated.id)
            nGenerated = calculateSceneEntityCount(false, true)
        } else {
            nSaved += scene.entityCount
        }
      }
    }
  }
  return nSaved + nGenerated
})

function clearSelection() {
  markedStateScenes.mutate(function(value) {
    foreach (k, _v in value)
      value[k] = false
  })

  selectionStateEntities.mutate(function(value) {
    foreach (k, _v in value)
      value[k] = false
  })
}

function scrollScenesBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("item" in desc) && (markedStateScenes.get()?[desc.item?.scene.id] || selectionStateEntities.get()?[desc.item?.entity.id])
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
    watch = [numMarkedScenesEntityCount, filteredScenesCount, filteredScenesEntityCount, markedStateScenes, selectedEntities]
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
  onChange = @(text) filterString.set(text)
  onEscape = @() set_kb_focus(null)
  onReturn = @() set_kb_focus(null)
  onClear = function() {
    filterString.set("")
    set_kb_focus(null)
  }
})

function getSelectedScenesIndicies(scenes) {
  return scenes.get()?.filter(@(marked, _sceneId) marked).keys()
}

function getAllSelectedItems() {
  let selection = []
  selection.extend(markedStateScenes?.get().filter(@(marked, _sceneId) marked).keys().map(function (value) {
    let item = {}
    item.id <- value
    item.isEntity <- false
    return item
  }))

  selection.extend(selectionStateEntities?.get().filter(@(selected, _eid) selected).keys().map(function (value) {
    let item = {}
    item.id <- value
    item.isEntity <- true
    return item
  }))

  return selection
}

function markAllObjects() {
  clearSelection()
  foreach (item in filteredItems.get()) {
    if (item?.scene != null) {
      markedStateScenes.get()[item.scene.id] <- true
    }
    else if (item?.entity != null) {
      selectionStateEntities.get()[item.entity.id] <- true
    }
  }

  markedStateScenes.trigger()
  selectionStateEntities.trigger()
}

function selectObjects() {
  entity_editor?.get_instance().selectObjects(getAllSelectedItems())
}

function initScenesList() {
  foreach (scene in getAllScenes()) {
    local isMarked = markedScenes.get()?[scene.id] ?? false
    local isExpanded = expandedStateScenes.get()?[scene.id] ?? false

    markedStateScenes.get()[scene.id] <- isMarked
    expandedStateScenes.get()[scene.id] <- isExpanded
  }

  local wasFakeSceneExpanded = expandedStateScenes.get()?[ecs.INVALID_SCENE_ID] ?? false
  markedStateScenes.set(markedStateScenes.get().filter(@(_val, key) key in sceneIdMap.get()))
  expandedStateScenes.set(expandedStateScenes.get().filter(@(_val, key) key in sceneIdMap.get()))

  expandedStateScenes.get()[ecs.INVALID_SCENE_ID] <- wasFakeSceneExpanded

  markedStateScenes.trigger()
  expandedStateScenes.trigger()
}

function initEntitiesList() {
  let entities = entity_editor?.get_instance().getEntities("") ?? []
  foreach (eid in entities) {
    let isSelected = selectionStateEntities.get()?[eid] ?? false
    selectionStateEntities.get()[eid] <- isSelected
  }
  allEntities.set({})
  allEntities.mutate(function(value) {
    foreach (eid in entities) {
      local sceneId = entity_editor?.get_instance().getEntityRecordSceneId(eid) ?? ecs.INVALID_SCENE_ID

      let entries = value?[sceneId]

      if (entries == null) {
        value[sceneId] <- [eid]
      }
      else {
        value[sceneId].append(eid)
      }
    }
  })
  selectionStateEntities.trigger()
}

function initLists() {
  initScenesList();
  initEntitiesList();
}

sceneListUpdateTrigger.subscribe_with_nasty_disregard_of_frp_update(@(_v) initLists())
allScenesWatcher.subscribe_with_nasty_disregard_of_frp_update(@(_v) initLists())

addEntityCreatedCallback(@(_eid) initLists())
addEntityRemovedCallback(@(_eid) initLists())

function isItemSelected(item) {
  if (item?.text != null) {
    return false
  }

  return item?.scene != null ? markedStateScenes?.get()[item.scene.id] : selectionStateEntities?.get()[item.entity.id]
}

function getItemParentScene(item) {
  return item?.scene != null ? item.scene.parent : (item?.entity != null ? item.entity.parentSceneId : item.parentSceneId)
}

function getTreeControl(item, ind) {
  function getCurrentScene() {
    if (item?.scene != null) {
      return getScene(item.scene.id)
    }
    else if (item?.entity != null) {
      return getScene(item.entity.parentSceneId)
    }
    else {
      return item.parentSceneId
    }
  }

  let isScene = item?.scene != null
  local offset = isScene ? 0 : 1;
  local currentScene = getCurrentScene()

  while (currentScene?.hasParent) {
    ++offset
    currentScene = sceneIdMap.get()?[currentScene.parent]
  }

  let objs = []
  local currentOffset = 0
  while (currentOffset < offset - 1) {
    objs.append(
      {
        size = [hdpx(TREE_CONTROL_CONTROL_WIDTH), flex()]
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        children = {
          rendObj = ROBJ_SOLID
          size = [1, flex()]
          color = TREE_CONNECTIONS_COLOR
        }
      }
    )

    ++currentOffset
  }

  if ((isScene && !(item.scene?.importDepth == 0 || (item.scene?.importDepth != 0 && !entity_editor?.get_instance().isChildScene(3, item.scene.id))))
    || !isScene) {
    if (ind + 1 == filteredItems.get().len() || item.depth > filteredItems.get()[ind + 1].depth) {
      objs.append(
        {
          size = [hdpx(TREE_CONTROL_CONTROL_WIDTH), flex()]
          valign = ALIGN_CENTER
          halign = ALIGN_RIGHT
          flow = FLOW_HORIZONTAL
          children = [
            {
              size = [1, flex()]
              flow = FLOW_VERTICAL
              children = [
                {
                  rendObj = ROBJ_SOLID
                  valign = ALIGN_TOP
                  size = [1, flex()]
                  color = TREE_CONNECTIONS_COLOR
                }
                {
                  valign = ALIGN_TOP
                  size = [1, flex()]
                }
              ]
            }
            {
              halign = ALIGN_RIGHT
              rendObj = ROBJ_SOLID
              size = [hdpx(TREE_CONTROL_CONTROL_WIDTH) / 2, 1]
              color = TREE_CONNECTIONS_COLOR
            }
          ]
        }
      )
    }
    else {
      objs.append(
        {
          size = [hdpx(TREE_CONTROL_CONTROL_WIDTH), flex()]
          valign = ALIGN_CENTER
          halign = ALIGN_RIGHT
          flow = FLOW_HORIZONTAL
          children = [
            {
              rendObj = ROBJ_SOLID
              size = [1, flex()]
              color = TREE_CONNECTIONS_COLOR
            }
            {
              halign = ALIGN_RIGHT
              rendObj = ROBJ_SOLID
              size = [hdpx(TREE_CONTROL_CONTROL_WIDTH) / 2, 1]
              color = TREE_CONNECTIONS_COLOR
            }
          ]
        }
      )
    }
  }

  if (isScene && item.scene.hasChildren) {
    objs.append({
      size = [hdpx(TREE_CONTROL_CONTROL_WIDTH), flex()]
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        rendObj = ROBJ_SOLID
        behavior = Behaviors.Button
        color = Color(224, 224, 224)
        size = const [ hdpx(14), hdpx(14) ]
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = {
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          rendObj = ROBJ_TEXT
          text = expandedStateScenes.get()[item.scene.id] ? "-" : "+"
          color = Color(0, 0, 0)
        }

        onClick = function () {
          expandedStateScenes.mutate(function(value) {
            value[item.scene.id] <- !value?[item.scene.id]
          })
        }
      }
    })
  }

  return objs
}

function getRowText(item) {
  if (item?.scene != null) {
    return sceneToText(item.scene)
  }
  else if (item?.entity != null) {
    return entityToTxt(item.entity.id)
  }
  else {
    return item.text
  }
}

function listSceneRow(item, idx) {
  return watchElemState(function(sf) {
    let isScene = item?.scene != null
    let isMarked = isItemSelected(item)
    let textColor = isMarked ? colors.TextDefault : (isScene ? Color(50, 166, 168) : colors.TextDarker)
    let rowColor = isMarked ? colors.Active
    : sf & S_TOP_HOVER ? colors.GridRowHover
    : colors.GridBg[idx % colors.GridBg.len()]

    let canBeDropped = Computed(function () {
      if (itemDragData.get() == null || dragDestData.get() == null) {
        return false
      }

      let dragDest = dragDestData.get()
      if (dragDest.item?.entity != null && dragDropPositionData.get() == null) {
        return false
      }

      if (dragDropPositionData.get() != null && isFilteringEnabled.get()) {
        return false
      }

      let dragDestScene = dragDest.item?.scene != null
        ? dragDest.item.scene
        : getScene(entity_editor?.get_instance().getEntityRecordSceneId(dragDest.item.entity.id))
      if (dragDestScene == null || (!canSceneBeModified(dragDestScene) && dragDestScene.id != ecs.INVALID_SCENE_ID)) {
        return false
      }

      function isInHierarchy(sceneId) {
        local destScene = dragDest.item?.scene != null ? dragDest.item.scene : sceneIdMap?.get()[getItemParentScene(dragDest.item)]
        while (destScene != null) {
          if (destScene.id == sceneId) {
            return true
          }

          destScene = sceneIdMap?.get()[destScene.parent]
        }

        return false
      }

      function notImport(draggedItem) {
        local scene = sceneIdMap?.get()[draggedItem.isEntity ? entity_editor?.get_instance().getEntityRecordSceneId(draggedItem.id) : draggedItem.id]
        return !canSceneBeModified(scene)
      }

      foreach (draggedItem in itemDragData.get()) {
        if (!draggedItem.isEntity) {
          if (isInHierarchy(draggedItem.id) || draggedItem.id == ecs.INVALID_SCENE_ID || dragDestScene.id == ecs.INVALID_SCENE_ID) {
            return false
          }
        }

        if (notImport(draggedItem)) {
          return false
        }
      }

      return true
    })

    let dragColor = Computed(function () {
      return (sf & S_DRAG) ? Color(255,255,0) : (!canBeDropped.get() ? Color(255,0,0) : Color(255, 255, 255))
    })

    function getSeparatorColor(position) {
      if (dragDestData.get() != null && dragDropPositionData.get() != null) {
        local destPos = dragDropPositionData.get() > 0 ? 0 : -1
        if (position == dragDestData.get().index + destPos) {
          if (canBeDropped.get()) {
            return Color(255, 255, 255)
          }
          else {
            return Color(255, 0, 0)
          }
        }
      }

      return Color(0, 0, 0)
    }

    return {
      rendObj = ROBJ_SOLID
      size = FLEX_H
      color = rowColor
      item
      watch = [expandedStateScenes]
      behavior = item?.text == null ? [Behaviors.TrackMouse, Behaviors.DragAndDrop] : []
      flow = FLOW_HORIZONTAL
      eventPassThrough = true
      dropData = item

      canDrop = function(_data) {
        let data = {}
        data.item <- item
        data.index <- idx
        dragDestData.set(data)
        return canBeDropped.get()
      }

      onDrop = function(_data) {
        if (dragDestData.get() == null || itemDragData.get() == null) {
          return
        }

        if (dragDropPositionData.get() == null) {
          let dragDest = dragDestData.get()
          if (dragDest.item?.entity != null) {
            return
          }

          entity_editor?.get_instance().setSceneNewParent(dragDest.item.scene.id, itemDragData.get())
        }
        else {
          let dragDest = dragDestData.get()
          entity_editor?.get_instance().setSceneNewParentAndOrder(getItemParentScene(dragDest.item),
            dragDropPositionData.get() < 0 ? dragDest.item.order : dragDest.item.order + 1, itemDragData.get())
        }
      }

      onMouseMove = function (event) {
        if (sf & S_DRAG) {
          dragDropPositionData.set(null)
          dragDestData.set(null)
        }

        if (dragDestData.get()) {
          let rect = event.targetRect
          let elemH = rect.b - rect.t
          let borderSize = elemH * DROP_BORDER_SIZE
          let relY = (event.screenY - rect.t)

          if (relY < borderSize) {
            dragDropPositionData.set(-1)
          }
          else if (relY > elemH - borderSize) {
            dragDropPositionData.set(1)
          }
          else {
            dragDropPositionData.set(null)
          }
        }
      }

      onDragMode = function(on, _val) {
        let selectedIds = getAllSelectedItems()

        if (isMarked) {
          itemDragData.set(on ? selectedIds : null)
        }
        else {
          let dragItem = {}
          dragItem.id <- isScene ? item.scene.id : item.entity.id
          dragItem.isEntity <- !isScene
          itemDragData.set(on ? [dragItem] : null)
        }

        if (!on) {
          dragDestData.set(null)
        }
      }

      onDoubleClick = function(_evt) {
        clearSelection()
        if (isScene) {
          markedStateScenes.mutate(function(value) {
            value[item.scene.id] <- true
          })
        }
        else {
          selectionStateEntities.mutate(function(value) {
            value[item.entity.id] <- true
          })
        }
        selectObjects()
      }

      onClick = function(evt) {
        if (evt.shiftKey) {
          local selCount = 0
          foreach (_k, v in markedStateScenes.get()) {
            if (v)
              ++selCount
          }
          foreach (_k, v in selectionStateEntities.get()) {
            if (v)
              ++selCount
          }
          if (selCount > 0) {
            local idx1 = -1
            local idx2 = -1
            foreach (i, filteredItem in filteredItems.get()) {
              if (item == filteredItem) {
                idx1 = i
                idx2 = i
              }
            }
            foreach (i, filteredItem in filteredItems.get()) {
              if ((filteredItem?.scene != null && markedStateScenes.get()?[filteredItem.scene.id])
                || (filteredItem?.entity != null && selectionStateEntities.get()?[filteredItem.entity.id])) {
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
                  let filteredItem = filteredItems.get()[i]
                  if (filteredItem?.scene != null) {
                    value[filteredItem.scene.id] <- !evt.ctrlKey
                  }
                }
              })
              selectionStateEntities.mutate(function(value) {
                for (local i = idx1; i <= idx2; i++) {
                  let filteredItem = filteredItems.get()[i]
                  if (filteredItem?.entity != null) {
                    value[filteredItem.entity.id] <- !evt.ctrlKey
                  }
                }
              })
            }
          }
        }
        else if (evt.ctrlKey) {
          if (isScene) {
            markedStateScenes.mutate(function(value) {
              value[item.scene.id] <- !value?[item.scene.id]
            })
          }
          else {
            selectionStateEntities.mutate(function(value) {
              value[item.entity.id] <- !value?[item.entity.id]
            })
          }
        }
        else {
          local wasMarked = isItemSelected(item)
          clearSelection()
          if (!wasMarked) {
            if (isScene) {
              markedStateScenes.mutate(function(value) {
                value[item.scene.id] <- true
              })
            }
            else {
              selectionStateEntities.mutate(function(value) {
                value[item.entity.id] <- true
              })
            }
          }
        }
      }

      children = [
        {
          flow = FLOW_VERTICAL
          size = [flex(), SIZE_TO_CONTENT]
          children = [
            @() {
              rendObj = ROBJ_SOLID
              watch = [itemDragData, dragDestData, dragDropPositionData]
              size = [flex(), 1]
              color = getSeparatorColor(idx - 1)
            }
            {
              flow = FLOW_HORIZONTAL
              children = [
                {
                  halign = ALIGN_CENTER
                  valign = ALIGN_CENTER
                  flow = FLOW_HORIZONTAL
                  size = [ SIZE_TO_CONTENT, flex() ]
                  padding = [0, fsh(0.5), 0, fsh(0.5)]
                  children = getTreeControl(item, idx)
                }
                @() {
                  rendObj = ROBJ_TEXT
                  text = getRowText(item)
                  watch = [itemDragData, dragDestData, dragDropPositionData]
                  padding = [fsh(0.5), 0, fsh(0.5), 0]
                  color = (dragDestData?.get().item == item && dragDropPositionData.get() == null) || (sf & S_DRAG) ? dragColor.get() : textColor
                }
              ]
            }
            @() {
              rendObj = ROBJ_SOLID
              watch = [itemDragData, dragDestData, dragDropPositionData]
              size = [flex(), 1]
              color = getSeparatorColor(idx)
            }
          ]
        }
      ]
    }
  })
}

sceneSortState.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  sceneSortFuncCache = v?.func
  selectedEntities.trigger()
  markedStateScenes.trigger()
  initLists()
})

de4workMode.subscribe(@(_) gui_scene.resetTimeout(0.1, initLists))

const selectSceneUID = "select_scene_modal_window"

let gamebase = get_arg_value_by_name("gamebase")
let root     = gamebase != null ? $"{gamebase}/" : ""
let selectedImport = Watched("")

let addImportFilter = nameFilter(filterImportString, {
  placeholder = "Filter by name"
  onChange = @(text) filterImportString.set(text)
  onEscape = @() set_kb_focus(null)
  onReturn = @() set_kb_focus(null)
  onClear = function() {
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

      onClick = @() selectedImport.set(scene)

      children = {
        rendObj = ROBJ_TEXT
        text = scene
        color = colors.TextDefault
        margin = fsh(0.5)
      }
    }
  })
}

function isAnyEntitySelected() {
  return selectionStateEntities?.get().filter(@(val, _) val).len() != 0
}

let doImportScene = function(scenePath) {
  let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
  if (selectedSceneIds?.len() == 1 && !isAnyEntitySelected()) {
    entity_editor?.get_instance().addImportScene(selectedSceneIds[0], scenePath)
    expandedStateScenes?.mutate(function(value) {
      value[selectedSceneIds[0]] = true
    })
    markedScenes.trigger()
    updateAllScenes()
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
      size = const [hdpx(700), hdpx(768)]
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
  if (selectedSceneIds?.len() == 1 && !isAnyEntitySelected()) {
    let path = $"{baseScenePath}{sceneName}.blk"
    mkpath($"%gameBase/{path}")
    let data = datablock()
    data.saveToTextFile($"%gameBase/{path}");
    entity_editor?.get_instance().addImportScene(selectedSceneIds[0], path)
    expandedStateScenes?.mutate(function(value) {
      value[selectedSceneIds[0]] = true
    })
    updateAllScenes()
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

function createSelectButton() {
  return textButton("Select", selectObjects)
}

let canAddImport = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds?.len() != 1 || (selectionStateEntities.get() != null && isAnyEntitySelected())) {
      return false
    }

    local scene = sceneIdMap?.get()[selectedSceneIds[0]]
    if (scene?.loadType != 3) {
      return false
    }

    return canSceneBeModified(scene)
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
    if (selectedSceneIds == null || selectedSceneIds.len() == 0 || isAnyEntitySelected()) {
      return false
    }

    foreach (id in selectedSceneIds) {
      local scene = sceneIdMap?.get()[id]
      if (scene == null || scene.importDepth == 0 || !canSceneBeModified(scene)) {
        return false
      }
    }

    return true
  })

  return textButton("Remove", function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds) {
      entity_editor?.get_instance().removeScenes(selectedSceneIds)
      updateAllScenes()
    }
  }, { off = !canRemoveScenes.get(), disabled = Computed(@() !canRemoveScenes.get() )})
}

const setSceneNameUID = "set_scene_name_modal_window"

function createSetNameButton() {
  let canSetName = Computed(function() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds == null || selectedSceneIds.len() != 1 || isAnyEntitySelected()) {
      return false
    }

    return sceneIdMap.get()?[selectedSceneIds[0]].loadType == 3;
  })

  function getSelectedPrettyName() {
    let selectedSceneIds = getSelectedScenesIndicies(markedStateScenes)
    if (selectedSceneIds?.len() == 1 && !isAnyEntitySelected()) {
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
          updateAllScenes()
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
    }
  }

  function onPivotYChanged(val) {
    if (isStringFloat(val)) {
      entity_editor?.get_instance().setScenePivot(sceneIndex.get(),
        Point3(pivotX.get().tofloat(), val.tofloat(), pivotZ.get().tofloat()))
    }
  }

  function onPivotZChanged(val) {
    if (isStringFloat(val)) {
      entity_editor?.get_instance().setScenePivot(sceneIndex.get(),
        Point3(pivotX.get().tofloat(), pivotY.get().tofloat(), val.tofloat()))
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
            size = const [ hdpx(300), SIZE_TO_CONTENT ]
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

function createFilterControls() {
  let stateFlags = Watched(0)

  return @() {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    halign = ALIGN_LEFT
    valign = ALIGN_CENTER

    watch = [stateFlags, filterSelectedEntities]

    children = [
      {
        rendObj = ROBJ_TEXT
        text = "All"
        color = colors.TextDefault
        margin = fsh(0.5)
      }
      {
        rendObj = ROBJ_SOLID
        size = [hdpx(46), hdpx(25)]
        color = colors.ControlBgOpaque
        behavior = Behaviors.Button
        onClick = @() filterSelectedEntities.set(!filterSelectedEntities.get())
        onElemState = @(nsf) stateFlags.set(nsf)
        children = {
          flow = FLOW_HORIZONTAL
          margin = hdpx(3)
          size = flex()
          children = [
            {
              rendObj = ROBJ_SOLID
              size = flex()
              color = !filterSelectedEntities.get()
                ? ((stateFlags.get() & S_HOVER) ? colors.Hover : Color(115, 115, 115))
                : colors.ControlBgOpaque
            }
            {
              rendObj = ROBJ_SOLID
              size = flex()
              color = filterSelectedEntities.get()
                ? ((stateFlags.get() & S_HOVER) ? colors.Hover : Color(115, 115, 115))
                : colors.ControlBgOpaque
            }
          ]
        }
      }
      {
        rendObj = ROBJ_TEXT
        text = "Only selected"
        color = colors.TextDefault
        margin = fsh(0.5)
      }
      mkCheckBox(showEntities, @() showEntities.set(!showEntities.get()))
      {
        rendObj = ROBJ_TEXT
        text = "Show entities"
        color = colors.TextDefault
        margin = fsh(0.5)
      }
    ]
  }
}

function createLocateButton() {
  function doLocate() {
    selectObjects()
    entity_editor?.get_instance().zoomAndCenter()
  }
  return textButton("Locate", doLocate)
}

function mkScenesList() {

  function listSceneContent() {
    local sRows = filteredItems.get().map(@(item, idx) listSceneRow(item, idx))

    return {
      watch = [selectedEntities, markedStateScenes, allScenesWatcher, filteredItems]
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
      onAttach = @() scrollScenesBySelection()
    }
  })

  return  @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = [allScenesWatcher, filteredItems, markedStateScenes, allEntities, selectionStateEntities, selectedEntities, sceneListUpdateTrigger]
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
        size = [flex(), SIZE_TO_CONTENT]
        children = [
          createFilterControls()
          hflow(
            HARight
            textButton("Expand all", function () {
              expandedStateScenes.mutate(function (value) {
                foreach (id, _state in value) {
                  value[id] = true
                }
              })
            })
            textButton("Collapse all", function () {
              expandedStateScenes.mutate(function (value) {
                foreach (id, _state in value) {
                  value[id] = false
                }
              })
            })
          )
        ]
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
          createImportExistingSceneButton()
          createImportNewSceneButton()
          createRemoveScenesButton()
          createSetNameButton()
          createSelectButton()
          createLocateButton()
        ]
      }
    ]
    hotkeys = [
      ["L.Ctrl A", markAllObjects]
    ]
  }
}

return {
  id = LoadedScenesWndId
  onAttach = initLists
  mkContent = mkScenesList
  saveState=true
}
