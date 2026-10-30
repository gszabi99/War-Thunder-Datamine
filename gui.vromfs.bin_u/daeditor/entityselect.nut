from "string" import format
from "math" import min, max
from "%darg/ui_imports.nut" import *
from "%sqstd/ecs.nut" import *
from "components/style.nut" import colors
from "%darg/laconic.nut" import *

let entity_editor = require_optional("entity_editor")
let { EntitySelectWndId, selectedEntities, de4workMode } = require("state.nut")
let { sceneIdMap } = require("sceneModel.nut")
let textButton = require("components/textButton.nut")
let closeButton = require("components/closeButton.nut")
let { setTooltip } = require("components/cursors.nut")
let { mkFilteredList, mkListFilter } = require("components/mkFilteredList.nut")
let { makeVertScroll } = require("%daeditor/components/scrollbar.nut")
let { getEntityExtraName, getSceneLoadTypeText } = require("%daeditor/daeditor_es.nut")
let { selection, matchEntityByScene } = require("selection.nut")
let mkSortModeButton = require("components/mkSortModeButton.nut")
let { addModalWindow, removeModalWindow } = require("%daeditor/components/modalWindows.nut")

let selectedGroup = Watched("")

let markedEids = mkWatched(persist, "markedEids", {})
let filterString = mkWatched(persist, "filterString", "")
let filterEntitiesByMarkedScenes = mkWatched(persist, "filterEntitiesByMarkedScenes", true)
let allEntities = mkWatched(persist, "allEntities", [])

let statusAnimTrigger = { lastN = null }
local locateOnDoubleClick = false

let entitySortState = Watched({})

local entitySortFuncCache = null

function matchEntityByText(eid, text): bool {
  if (text==null || text=="" || eid.tostring().contains(text))
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

let filteredEntites = Computed(function() {
  local entities = allEntities.get()
  if (filterString.get() != "")
    entities = entities.filter(@(eid) matchEntityByText(eid, filterString.get()))

  let markedScenes = selection.get().scenes
  if (filterEntitiesByMarkedScenes.get() && markedScenes.len() > 0) {
    entities = entities.filter(@(eid) matchEntityByScene(eid, markedScenes))
  }

  if (entitySortFuncCache != null) {
    entities = entities.slice(0)
    entities.sort(entitySortFuncCache)
  }
  return entities
})

let filteredEntitiesCount = Computed(@() filteredEntites.get().len())

let numMarkedEntities = Computed(@() markedEids.get().len())

let toMarks = @(eids) eids.map(@(eid) [eid, true]).totable()

let listedByText = @() allEntities.get().filter(@(eid) matchEntityByText(eid, filterString.get()))

let selectAllFiltered = @() markedEids.set(toMarks(listedByText()))

let selectNone = @() markedEids.set({})


function selectInvert() {
  let marked = markedEids.get()
  markedEids.set(toMarks(listedByText().filter(@(eid) eid not in marked)))
}

function doSelect() {
  entity_editor?.get_instance().selectEntities(markedEids.get().keys())
}

function doLocate() {
  doSelect()
  entity_editor?.get_instance().zoomAndCenter()
}

function statusLine() {
  let nMrk = numMarkedEntities.get()
  let nSel = selectedEntities.get().len()

  if (statusAnimTrigger.lastN != null && statusAnimTrigger.lastN != nSel)
    anim_start(statusAnimTrigger)
  statusAnimTrigger.lastN = nSel

  return {
    watch = [numMarkedEntities, filteredEntitiesCount, selectedEntities]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    children = [
      {
         rendObj = ROBJ_TEXT
         size = FLEX_H
         text = format(" %d %s marked, %d selected", nMrk, nMrk==1 ? "entity" : "entities", nSel)
         animations = [
           { prop=AnimProp.color, from=colors.HighlightSuccess, duration=0.5, trigger=statusAnimTrigger }
         ]
      }
      {
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        size = FLEX_H
        text = format("%d listed   ", filteredEntitiesCount.get())
        color = Color(170,170,170)
     }
    ]
  }
}


let filter = mkListFilter(filterString)

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
  entity_editor?.get_instance().selectEntities(eids)
}

let removeSelectedByEditorTemplate = @(tname) tname.replace("+daeditor_selected+","+").replace("+daeditor_selected","").replace("daeditor_selected+","")

let sceneInfoStyle = const { fontSize = hdpx(17), color=Color(180,180,180,120) }

function mkEntitySceneTooltip(loadType, id) {
  if (loadType > 0 && id >= 0) {
    local loadTypeText = "MAIN"
    local idSeparator = ""
    local indexText = ""
    local sceneInfo = sceneIdMap.get()?[id]
    if (sceneInfo && sceneInfo.importDepth != 0) {
      loadTypeText = getSceneLoadTypeText(sceneInfo)
      idSeparator = ":"
      indexText = sceneInfo.id
    }
    return @() {
      rendObj = ROBJ_BOX
      fillColor = Color(30, 30, 30, 220)
      borderColor = Color(50, 50, 50, 110)
      size = SIZE_TO_CONTENT
      borderWidth = hdpx(1)
      padding = fsh(1)
      flow = FLOW_VERTICAL
      children = [
        txt($"{loadTypeText}{idSeparator}{indexText}", sceneInfoStyle)
        sceneInfo != null ? txt($"{sceneInfo.path}", sceneInfoStyle) : null
      ]
    }
  }
  return null
}



function mkEntityLabel(eid, row) {
  let isMarked = row.isSelected
  let isSelected = row.scope.Computed(@() eid in selectedEntities.get())

  return function() {
    let extraName = getEntityExtraName(eid)
    let extra = (extraName != null) ? $"/ {extraName}" : ""

    let tplName = g_entity_mgr.getEntityTemplateName(eid) ?? ""
    let name = removeSelectedByEditorTemplate(tplName)
    let div = (tplName != name) ? "•" : "|"

    let loadTypeVal = entity_editor?.get_instance().getEntityRecordLoadType(eid) ?? 0
    let sceneId = entity_editor?.get_instance().getEntityRecordSceneId(eid) ?? -1
    local loadType = "MAIN"
    local idSeparator = ""
    local index = ""
    if (loadTypeVal > 0 && sceneId >= 0) {
      let scene = sceneIdMap.get()?[sceneId]
      if (scene != null && scene.importDepth != 0) {
        loadType = getSceneLoadTypeText(scene)
        idSeparator = ":"
        index = scene.id
      }
    } else {
      loadType = ""
    }

    return {
      watch = [isSelected, isMarked, sceneIdMap]
      rendObj = ROBJ_TEXT
      text = $"{eid}  {div}  {name} {extra}  {loadType}{idSeparator}{index}"
      color = isMarked.get() ? colors.TextDefault : colors.TextDarker
      margin = fsh(0.5)
    }
  }
}

function setMark(marks, eid, on) {
  if (on) {
    marks[eid] <- true
  }
  else {
    marks.$rawdelete(eid)
  }
}

function onEntityClick(eid, evt) {
  if (evt.shiftKey) {
    let marked = markedEids.get()
    let listed = filteredEntites.get()
    let clicked = listed.indexof(eid)
    if (marked.len() == 0 || clicked == null) {
      return
    }
    local idx1 = clicked
    local idx2 = clicked
    foreach (i, listedEid in listed) {
      if (listedEid in marked) {
        idx1 = min(idx1, i)
        idx2 = max(idx2, i)
      }
    }
    markedEids.mutate(function(marks) {
      foreach (listedEid in listed.slice(idx1, idx2 + 1)) {
        setMark(marks, listedEid, !evt.ctrlKey)
      }
    })
  }
  else if (evt.ctrlKey) {
    markedEids.mutate(@(marks) setMark(marks, eid, eid not in marks))
  }
  else {
    markedEids.set({ [eid] = true })
  }
}

function onEntityDoubleClick(eid, evt) {
  if (locateOnDoubleClick) { doLocate(); return }
  locateOnDoubleClick = true
  gui_scene.resetTimeout(0.3, @() locateOnDoubleClick = false)
  doSelectEid(eid, evt.ctrlKey)
}

function onEntityHover(eid, on) {
  if (!on) {
    setTooltip(null)
    return
  }
  let loadType = entity_editor?.get_instance().getEntityRecordLoadType(eid) ?? 0
  let sceneId = entity_editor?.get_instance().getEntityRecordSceneId(eid) ?? -1
  setTooltip(mkEntitySceneTooltip(loadType, sceneId))
}



let entitiesList = mkFilteredList({
  items = filteredEntites
  selected = markedEids
  isSelected = @(marked, eid) eid in marked
  revealOnSelect = false
  revealOnItems = false
  mkRow = mkEntityLabel
  onClick = onEntityClick
  onDoubleClick = onEntityDoubleClick
  onHover = onEntityHover
})


function initEntitiesList() {
  let entities = entity_editor?.get_instance().getEntities(selectedGroup.get()) ?? []
  let selected = selectedEntities.get()
  markedEids.set(toMarks(entities.filter(@(eid) eid in selected)))
  allEntities.set(entities)
}

entitySortState.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  entitySortFuncCache = v?.func
  initEntitiesList()
})

selectedGroup.subscribe_with_nasty_disregard_of_frp_update(@(_) initEntitiesList())
de4workMode.subscribe(@(_) gui_scene.resetTimeout(0.1, initEntitiesList))

function entitySceneFilterCheckbox() {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let hoverFlag = Computed(@() stateFlags.get() & S_HOVER)

  function onClick() {
    filterEntitiesByMarkedScenes.set(!filterEntitiesByMarkedScenes.get())
    return
  }

  return function () {
    local mark = null
    if (filterEntitiesByMarkedScenes.get()) {
      mark = {
        rendObj = ROBJ_SOLID
        color = (hoverFlag.get() != 0) ? colors.Hover : colors.Interactive
        group
        size = const [pw(50), ph(50)]
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
      }
    }

    return {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER

      watch = [filterEntitiesByMarkedScenes]

      children = [
        {
          size = const [fontH(80), fontH(80)]
          rendObj = ROBJ_SOLID
          color = colors.ControlBg

          behavior = Behaviors.Button
          group

          children = mark

          onElemState = @(sf) stateFlags.set(sf)

          onClick
        }
        {
          rendObj = ROBJ_TEXT
          size = FLEX_H
          text = "Pre-filter based on marked scenes"
          color = colors.TextDefault
          margin = fsh(0.5)
        }
      ]
    }
  }
}

function mkEntitySelect() {
  let templatesGroups = ["(all workset entities)"].extend(entity_editor?.get_instance().getEcsTemplatesGroups())

  const WORKSET_FILTER = "workset filter"
  let closeWorkset = @() removeModalWindow(WORKSET_FILTER)
  function mkSelectWorkSet(ws) {
    let hovered = Watched(false)
    let group = ElemGroup()
    return @() {
      watch = [hovered, selectedGroup]
      rendObj = ROBJ_BOX
      size = const [hdpx(300), SIZE_TO_CONTENT]
      group
      children = { rendObj = ROBJ_TEXT text = ws group, behavior = Behaviors.Marquee, scrollOnHover = true, size = FLEX_H delay = [0.1, 0.5], speed = hdpx(80)}
      padding = const [hdpx(1), hdpx(5)]
      key = ws
      borderWidth = hovered.get() ? hdpx(1) : 0
      fillColor = hovered.get()
        ? Color(30,30,30,5)
        : selectedGroup.get()==ws ? Color(100,120,120) : 0
      borderColor = Color(160,160,180)
      behavior = Behaviors.Button
      onHover = @(on) hovered.set(on)
      onClick = function(){
        selectedGroup.set(ws)
        closeWorkset()
      }
    }
  }
  return @() {
    flow = FLOW_VERTICAL
    gap = fsh(0.5)
    watch = [allEntities, selectedEntities]
    size = flex()
    children = [
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        children = [
          mkSortModeButton(entitySortState)
          const { size = [sw(0.2), SIZE_TO_CONTENT] }
          filter
          function() {
            
            return {
              size = const [sw(11), sh(2.7)]
              watch = selectedGroup

              children = textButton((selectedGroup.get() ?? "")=="" ? "_unspecified_" : selectedGroup.get(), @() addModalWindow({
                key = WORKSET_FILTER
                size = flex()
                hotkeys = [["Esc", closeWorkset]]
                padding = hdpx(20)
                rendObj = ROBJ_SOLID
                color = Color(30, 30, 30)
                children = [
                  { hplace = ALIGN_RIGHT vplace = ALIGN_TOP children = closeButton(closeWorkset)}
                  { hplace = ALIGN_LEFT vplace = ALIGN_TOP children = {rendObj = ROBJ_TEXT text = "Select filter for working set"}}
                  { padding = [sh(5), sh(2) ] size = flex() children = makeVertScroll(wrap(templatesGroups.map(mkSelectWorkSet), {width = sw(80)}))}
                ]
              }))
            }
          }
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        children = entitySceneFilterCheckbox()
      }
      entitiesList
      statusLine
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
        halign = ALIGN_CENTER
        children = [
          textButton("All filtered", selectAllFiltered)
          textButton("None",   selectNone)
          textButton("Invert", selectInvert)
        ]
      }
      {
        flow = FLOW_HORIZONTAL
        size = FLEX_H
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
  onAttach = initEntitiesList
  id = EntitySelectWndId
  mkContent = mkEntitySelect
  saveState=true
  headerText = "Entity Select"
}
