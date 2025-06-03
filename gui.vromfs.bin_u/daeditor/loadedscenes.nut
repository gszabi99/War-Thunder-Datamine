from "%darg/ui_imports.nut" import *

from "%sqstd/ecs.nut" import *

let {LoadedScenesWndId, selectedEntities, markedScenes, de4workMode,
  entitySource, entitySources, initEntitySources} = require("state.nut")
let {colors} = require("components/style.nut")
let textButton = require("components/textButton.nut")
let nameFilter = require("components/nameFilter.nut")
let {makeVertScroll} = require("%daeditor/components/scrollbar.nut")
let combobox = require("%daeditor/components/combobox.nut")
let {getEntityExtraName, getSceneLoadTypeText, getSceneId, getSceneIdOf, getSceneIdLoadType, getSceneIdIndex} = require("%daeditor/daeditor_es.nut")
let { format } = require("string")
let entity_editor = require("entity_editor")
let mkSortModeButton = require("components/mkSortModeButton.nut")
let {defaultScenesSortMode, mkSceneSortModeButton} = require("components/mkSortSceneModeButton.nut")
let scrollHandler = ScrollHandler()
let scrollHandlerEntities = ScrollHandler()
let markedStateScenes = Watched({})
let editedStateScenes = Watched({})
let filterString = mkWatched(persist, "filterString", "")
let filterScenesBySelectedEntities = mkWatched(persist, "filterScenesBySelectedEntities", true)
let allScenes = mkWatched(persist, "allScenes", [])
let allSceneCounts = mkWatched(persist, "allSceneCounts", [])
let allSceneIndices = mkWatched(persist, "allSceneIndices", [])
let filterStringEntities = mkWatched(persist, "filterStringEntities", "")
let selectionStateEntities = mkWatched(persist, "selectionStateEntities", {})
let allEntities = mkWatched(persist, "allEntities", [])
let filteredEntities = Watched([])

let sceneSortState = Watched(defaultScenesSortMode)

local sceneSortFuncCache = defaultScenesSortMode.func

let entitySortState = Watched({})

local entitySortFuncCache = null

let statusAnimTrigger = { lastN = null }

local locateOnDoubleClick = false

let numMarkedScenes = Computed(function() {
  local nSel = 0
  foreach (_sceneId, marked in markedStateScenes.get()) {
    if (marked)
      ++nSel
  }
  return nSel
})

let numSelectedEntities = Computed(function() {
  local nSel = 0
  foreach (v in selectionStateEntities.get()) {
    if (v)
      ++nSel
  }
  return nSel
})

let selectedEntitiesSceneIds = Computed(function() {
  local res = [[],  [],  [],  []]
  foreach (eid, _v in selectedEntities.get()) {
    local loadType = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
    if (loadType != 0) {
      local index = entity_editor.get_instance()?.getEntityRecordIndex(eid)
      res[loadType].append(index)
    }
  }
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
  local sceneId = getSceneIdOf(scene)
  local edit = editedStateScenes.value?[sceneId] ? "> " : "| "
  local idSeparator = ":"
  local loadType = "MAIN"
  local index = ""
  if (scene.importDepth != 0) {
    loadType = getSceneLoadTypeText(scene)
    index = scene.index
  }
  local path = scene.path
  local entityCount = scene.entityCount
  local order = scene.order
  local relation = ""
  if (sceneSortFuncCache == defaultScenesSortMode.func) {
    if (scene.hasParent) {
      local prefix = ""
      local loadTypeIndex = allSceneIndices.value[scene.loadType]
      local parentScene = allScenes.value[loadTypeIndex + scene.parent]
      while (parentScene.hasParent) {
        prefix = $"    {prefix}"
        parentScene = allScenes.value[loadTypeIndex + parentScene.parent]
      }
      relation = $"{prefix}{scene.imports > 0 ? "+- " : "-- "}"
    }
  }
  return $"{edit}{loadType}{idSeparator}{index}  {relation}{path} - Entities: {entityCount}  (#{order})"
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
  local scenes = allScenes.get().map(@(scene) scene) 
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

let filteredScenesCount = Computed(@() filteredScenes.get().len())

let filteredScenesEntityCount = Computed(function() {
  local eCount = 0
  foreach (scene in filteredScenes.get()) {
    eCount += scene.entityCount
  }
  return eCount
})

let numMarkedScenesEntityCount = Computed(function() {
  local nSel = 0
  foreach (scene in filteredScenes.get()) {
    if (markedStateScenes.get()?[getSceneIdOf(scene)])
      nSel += scene.entityCount
  }
  return nSel
})

function matchEntityByText(eid, text) {
  if (text==null || text=="" || eid.tostring().indexof(text)!=null)
    return true
  let tplName = g_entity_mgr.getEntityTemplateName(eid)
  if (tplName==null)
    return false
  if (tplName.tolower().contains(text.tolower()))
    return true
  let riExtraName = getEntityExtraName(eid)
  if (riExtraName != null && riExtraName.tolower().contains(text.tolower()))
    return true
  return false
}

function matchEntityByScene(eid) {
  local eLoadType = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
  local eIndex = entity_editor.get_instance()?.getEntityRecordIndex(eid)
  local sceneId = getSceneId(eLoadType, eIndex)
  return markedStateScenes.get()?[sceneId]
}

function matchEntityWithSceneRecord(eid) {
  local eLoadType = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
  return eLoadType != 0
}

function matchSavedEntity(eid, isSaved) {
  return entity_editor.get_instance()?.isSceneEntity(eid) == isSaved
}

local entitySourceStrings = ["Saved", "Generated", "Scene", "All entities"]
initEntitySources?(entitySourceStrings, entitySourceStrings[2])

function filterEntities() {
  local entities = allEntities.get()

  if (filterStringEntities.get() != "")
    entities = entities.filter(@(eid) matchEntityByText(eid, filterStringEntities.get()))

  local filterType = entitySourceStrings.indexof(entitySource.get())
  if (filterType == 0)
    entities = entities.filter(@(eid) matchSavedEntity(eid, true))
  else if (filterType == 1)
    entities = entities.filter(@(eid) matchSavedEntity(eid, false))
  else if (filterType == 2)
    entities = entities.filter(@(eid) matchEntityWithSceneRecord(eid))

  if (numMarkedScenes.value > 0)
    entities = entities.filter(@(eid) matchEntityByScene(eid))

  if (entitySortFuncCache != null)
    entities.sort(entitySortFuncCache)

  filteredEntities.set(entities)

  entity_editor.get_instance()?.unhideAll()
  entity_editor.get_instance()?.hideUnmarkedEntities(filteredEntities.get())
}

filterStringEntities.subscribe(@(_v) filterEntities())
entitySource.subscribe(@(_v) filterEntities())
markedStateScenes.subscribe(@(_v) filterEntities())
editedStateScenes.subscribe(@(_v) filterEntities())

let filteredEntitiesCount = Computed(@() filteredEntities.get().len())

function markScene(cb) {
  markedStateScenes.mutate(function(value) {
    foreach (k, v in value)
      value[k] = cb(k, v)
  })
}

function applyEntitySelection(cb) {
  selectionStateEntities.mutate(function(value) {
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
      if (markedStateScenes.value?[sceneId]) {
        local loadType = getSceneIdLoadType(sceneId)
        local index = getSceneIdIndex(sceneId)
        if (entity_editor.get_instance()?.isChildScene(loadType, index)) {
          entity_editor.get_instance()?.setChildSceneEditable(loadType, index, !edited)
          value[sceneId] = !edited
        }
      }
    }
  })
}

function scrollScenesBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("scene" in desc) && markedStateScenes.get()?[getSceneIdOf(desc.scene)]
  }, 2, false, true)
}

function scrollEntitiesBySelection() {
  scrollHandlerEntities.scrollToChildren(function(desc) {
    return ("eid" in desc) && selectionStateEntities.get()?[desc.eid]
  }, 2, false, true)
}

function scnTxt(count) { return count==1 ? "scene" : "scenes" }
function entTxt(count) { return count==1 ?  "entity" : "entities" }
function statusText(count, textFunc) { return format("%d %s", count, textFunc(count)) }

function statusLineScenes() {
  let sMrk = numMarkedScenes.get()
  let eMrk = numMarkedScenesEntityCount.get()
  let eRec = filteredScenesEntityCount.get()

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != sMrk)
    anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = sMrk

  return {
    watch = [numMarkedScenes, numMarkedScenesEntityCount, filteredScenesCount, filteredScenesEntityCount, markedStateScenes, selectedEntities]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        text = format(" %s, with %s, marked", statusText(sMrk, scnTxt), statusText(eMrk, entTxt))
        animations = [
          { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=statusAnimTrigger }
        ]
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = [flex(), SIZE_TO_CONTENT]
        text = format(" %s, with %s, listed", statusText(filteredScenesCount.get(), scnTxt), statusText(eRec, entTxt))
        color = Color(170,170,170)
      }
    ]
  }
}

let filter = nameFilter(filterString, {
  placeholder = "Filter by load-type/path/entities"

  function onChange(text) {
    filterString(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    filterString.update("")
    set_kb_focus(null)
  }
})

let filterEntitiesByName = nameFilter(filterStringEntities, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterStringEntities(text)
  }

  function onEscape() {
    set_kb_focus(null)
  }

  function onReturn() {
    set_kb_focus(null)
  }

  function onClear() {
    filterStringEntities.update("")
    set_kb_focus(null)
  }
})

let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

function listSceneRow(scene, idx) {
  return watchElemState(function(sf) {
    let sceneId = getSceneIdOf(scene)
    let isMarked = markedStateScenes.get()?[sceneId]
    let textColor = isMarked ? colors.TextDefault : colors.TextDarker
    let color = isMarked ? colors.Active
    : sf & S_TOP_HOVER ? colors.GridRowHover
    : colors.GridBg[idx % colors.GridBg.len()]

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      scene
      behavior = Behaviors.Button

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
              if (markedStateScenes.get()?[getSceneIdOf(filteredScene)]) {
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
                  value[getSceneIdOf(filteredScene)] <- !evt.ctrlKey
                }
              })
            }
          }
        }
        else if (evt.ctrlKey) {
          markedStateScenes.mutate(function(value) {
            value[sceneId] <- !value?[sceneId]
          })
        }
        else {
          local wasMarked = markedStateScenes.get()?[sceneId]
          markSceneNone()
          if (!wasMarked) {
            markedStateScenes.mutate(function(value) {
              value[sceneId] <- true
            })
          }
        }
      }

      children = {
        rendObj = ROBJ_TEXT
        text = sceneToText(scene)
        color = textColor
        margin = fsh(0.5)
      }
    }
  })
}

function listRowMoreLeft(num, idx) {
  return watchElemState(function(sf) {
    let color = (sf & S_TOP_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
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


function initScenesList() {
  local scenes = entity_editor.get_instance()?.getSceneImports() ?? []
  local sceneCounts = [0,  0,  0,  0]
  foreach (scene in scenes) {
    sceneCounts[scene.loadType] += 1
    local sceneId = getSceneId(scene.loadType, scene.index)
    local isMarked = markedScenes.value?[sceneId] ?? false
    markedStateScenes.value[sceneId] <- isMarked
    editedStateScenes.value[sceneId] <- false
  }
  allScenes(scenes)
  allSceneCounts(sceneCounts)
  allSceneIndices([0, 0, sceneCounts[1], sceneCounts[1] + sceneCounts[2]])
  markedStateScenes.trigger()
}

sceneSortState.subscribe(function(v) {
  sceneSortFuncCache = v?.func
  selectedEntities.trigger()
  markedStateScenes.trigger()
  initScenesList()
})

de4workMode.subscribe(@(_) gui_scene.resetTimeout(0.1, initScenesList))

function doSelect() {
  let eids = []
  foreach (k, v in selectionStateEntities.get()) if (v) eids.append(k)
  entity_editor.get_instance().selectEntities(eids)
  gui_scene.resetTimeout(0.1, function() {
    selectedEntities.trigger()
    selectionStateEntities.trigger()
  })
}

function doLocate() {
  let eids = []
  foreach (k, v in selectionStateEntities.get()) if (v) eids.append(k)
  entity_editor.get_instance().selectEntities(eids)
  entity_editor.get_instance().zoomAndCenter()
}

function doSelectEid(eid, mod) {
  let eids = []
  local found = false
  foreach (k, _v in selectedEntities.get()) {
    if (k == eid)
      found = true
    else if (mod)
      eids.append(k)
  }
  if (!found)
    eids.append(eid)
  entity_editor.get_instance().selectEntities(eids)
  gui_scene.resetTimeout(0.1, @() selectionStateEntities.trigger())
}

function statusLineEntities() {
  let nMrk = numSelectedEntities.get()
  let nSel = selectedEntities.get().len()

  return {
    watch = [numSelectedEntities, filteredEntitiesCount, selectedEntities]
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      {
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        text = format(" %d %s marked, %d selected", nMrk, nMrk==1 ? "entity" : "entities", nSel)
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = [flex(), SIZE_TO_CONTENT]
        text = format("%d listed", filteredEntitiesCount.get())
        color = Color(170,170,170)
      }
    ]
  }
}

function listEntityRow(eid, idx) {
  return watchElemState(function(sf) {
    let isSelected = selectionStateEntities.get()?[eid]
    let textColor = isSelected ? colors.TextDefault : colors.TextDarker
    let color = isSelected ? colors.Active
      : sf & S_TOP_HOVER ? colors.GridRowHover
      : colors.GridBg[idx % colors.GridBg.len()]

    let extraName = getEntityExtraName(eid)
    let extra = (extraName != null) ? $"/ {extraName}" : ""

    local tplName = g_entity_mgr.getEntityTemplateName(eid) ?? ""
    let name = removeSelectedByEditorTemplate(tplName)
    let div = (tplName != name) ? "•" : "|"

    local loadTypeVal = entity_editor.get_instance()?.getEntityRecordLoadType(eid)
    let loadType = getSceneLoadTypeText(loadTypeVal)
    let index = entity_editor.get_instance()?.getEntityRecordIndex(eid)

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color
      eid
      behavior = Behaviors.Button

      function onClick(evt) {
        if (evt.shiftKey) {
          local selCount = 0
          foreach (_k, v in selectionStateEntities.get()) {
            if (v)
              ++selCount
          }
          if (selCount > 0) {
            local idx1 = -1
            local idx2 = -1
            foreach (i, filteredEid in filteredEntities.get()) {
              if (eid == filteredEid) {
                idx1 = i
                idx2 = i
              }
            }
            foreach (i, filteredEid in filteredEntities.get()) {
              if (selectionStateEntities.get()?[filteredEid]) {
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
              selectionStateEntities.mutate(function(value) {
                for (local i = idx1; i <= idx2; i++) {
                  let filteredEid = filteredEntities.get()[i]
                  value[filteredEid] <- !evt.ctrlKey
                }
              })
            }
          }
        }
        else if (evt.ctrlKey) {
          selectionStateEntities.mutate(function(value) {
            value[eid] <- !value?[eid]
          })
        }
        else {
          applyEntitySelection(@(eid_, _cur) eid_==eid)
        }
      }

      onDoubleClick = function(evt) {
        if (locateOnDoubleClick) { doLocate(); return }
        locateOnDoubleClick = true
        gui_scene.resetTimeout(0.3, @() locateOnDoubleClick = false)
        doSelectEid(eid, evt.ctrlKey)
      }

      children = {
        rendObj = ROBJ_TEXT
        text = $"{eid}  {div}  {name} {extra}  {loadType}:{index}"
        color = textColor
        margin = fsh(0.5)
      }
    }
  })
}

function initEntitiesList() {
  let entities = entity_editor.get_instance()?.getEntities("") ?? []
  foreach (eid in entities) {
    let isSelected = selectedEntities.get()?[eid] ?? false
    selectionStateEntities.get()[eid] <- isSelected
  }
  allEntities(entities)
  selectionStateEntities.trigger()
}

entitySortState.subscribe(function(v) {
  entitySortFuncCache = v?.func
  selectedEntities.trigger()
  selectionStateEntities.trigger()
  initEntitiesList()
  filterEntities()
})

function initLists() {
  initScenesList();
  initEntitiesList();
}

function sceneFilterCheckbox() {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let hoverFlag = Computed(@() stateFlags.get() & S_HOVER)

  function onClick() {
    filterScenesBySelectedEntities.update(!filterScenesBySelectedEntities.get())
    return
  }

  return function () {
    local mark = null
    if (filterScenesBySelectedEntities.get()) {
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
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER

      watch = [filterScenesBySelectedEntities]

      children = [
        {
          size = [fontH(80), fontH(80)]
          rendObj = ROBJ_SOLID
          color = colors.ControlBg

          behavior = Behaviors.Button
          group

          children = mark

          onElemState = @(sf) stateFlags.update(sf)

          onClick
        }
        {
          rendObj = ROBJ_TEXT
          size = [flex(), SIZE_TO_CONTENT]
          text = "Pre-filter based on selected entities"
          color = colors.TextDefault
          margin = fsh(0.5)
        }
      ]
    }
  }
}

function mkScenesList() {

  function listSceneContent() {
    const maxVisibleItems = 250
    local sRows = filteredScenes.get().slice(0, maxVisibleItems).map(@(scene, idx) listSceneRow(scene, idx))
    if (sRows.len() < filteredScenes.get().len())
      sRows.append(listRowMoreLeft(filteredScenes.get().len() - sRows.len(), sRows.len()))

    return {
      watch = [selectedEntities, markedStateScenes, filteredScenes, editedStateScenes]
      size = [flex(), SIZE_TO_CONTENT]
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

  function listEntitiesContent() {
    const maxVisibleItems = 250
    let eRows = filteredEntities.get().slice(0, maxVisibleItems).map(@(eid, idx) listEntityRow(eid, idx))
    if (eRows.len() < filteredEntities.get().len())
      eRows.append(listRowMoreLeft(filteredEntities.get().len() - eRows.len(), eRows.len()))

    return {
      watch = [allEntities, selectedEntities, selectionStateEntities, filteredEntities]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = eRows
      behavior = Behaviors.Button
    }
  }

  let scrollListEntities = makeVertScroll(listEntitiesContent, {
    scrollHandlerEntities
    rootBase = {
      size = flex()
      function onAttach() {
        scrollEntitiesBySelection()
      }
    }
  })

  return  @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = [allScenes, filteredScenes, markedStateScenes, allEntities, filteredEntities, selectionStateEntities]
    size = flex()
    children = [
      {
        size = [flex(), SIZE_TO_CONTENT]
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
        children = sceneFilterCheckbox()
      }
      {
        size = flex()
        children = scrollListScenes
      }
      statusLineScenes
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("All filtered", markAllFiltered)
          textButton("None", markSceneNone)
          textButton("Invert", markScenesInvert)
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("Toggle editing", toggleEditing)
        ]
      }
      {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        children = [
          mkSortModeButton(entitySortState)
          { size = [sw(0.2), SIZE_TO_CONTENT] }
          filterEntitiesByName
          { size = [sw(0.2), SIZE_TO_CONTENT] }
          entitySources.get().len() <= 1 ? null : {
            size = [hdpx(150), fontH(150)]
            rendObj = ROBJ_SOLID
            color = colors.ControlBg
            children = combobox(entitySource, entitySources)
          }
        ]
      }
      {
        size = flex()
        children = scrollListEntities
      }
      statusLineEntities
      {
        flow = FLOW_HORIZONTAL
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_CENTER
        children = [
          textButton("Select", doSelect, {hotkeys=["^Enter"]})
          textButton("Locate", doLocate, {hotkeys=["^Z"]})
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

