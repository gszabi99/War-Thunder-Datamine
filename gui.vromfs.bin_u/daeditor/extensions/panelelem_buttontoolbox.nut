from "console" import command as console_command
from "%darg/ui_imports.nut" import *
let { mkPanelElemsButton } = require("panelElem.nut")

let makeToolBox = require("%daeditor/components/toolBox.nut")

let { showPointAction, namePointAction, propPanelVisible } = require("%daeditor/state.nut")
let {getEditMode=@() null, DE4_MODE_POINT_ACTION=null} = require_optional("daEditorEmbedded")

let toolboxShown = Watched(false)
let toolboxStates = Watched({})
let toolBoxComponent = makeToolBox(toolboxShown)

function getToolboxState(key){
  return toolboxStates.get()?[key]
}

function setToolboxState(key, val) {
  toolboxStates.mutate(@(v) v[key] <- val)
}

function runToolboxCmd(cmd, cmd2 = null, key = null, val = null) {
  if (cmd2 == "close")
    toolboxShown.set(false)
  console_command(cmd)
  if (cmd2 != null && cmd2 != "close")
    console_command(cmd2)
  if (key != null)
    setToolboxState(key, val)
}

function runToolboxCmd_toggleCollGeom() {
  if (!getToolboxState("coll"))
    runToolboxCmd("app.debug_collision", null, "coll", true)
  else
    runToolboxCmd("app.debug_collision", null, "coll", false)
}

function runToolboxCmd_toggleNavMesh() {
  if (!getToolboxState("nav"))
    runToolboxCmd("app.debug_navmesh 1", null, "nav", true)
  else
    runToolboxCmd("app.debug_navmesh 0", null, "nav", false)
}

function setToolboxPopupPos(x, y) {
  toolBoxComponent.setPos(x, y)
}

function clearToolboxOptions() {
  toolBoxComponent.clearOptions()
  toolboxStates.set({})
}

function addToolboxOption(on, key, val, name, cb, content, tooltip) {
  if (key != null)
    toolboxStates.mutate(@(v) v[key] <- val)
  toolBoxComponent.addOption(on, name, cb, content, tooltip)
}

function addToolboxOptions_CollGeomAndNavMesh() {
  addToolboxOption(@() getToolboxState("coll"), "coll", false, "CollGeom", @(_) runToolboxCmd_toggleCollGeom(), null, "Toggle collision geometry")
  addToolboxOption(@() getToolboxState("nav"),  "nav",  false, "NavMesh",  @(_) runToolboxCmd_toggleNavMesh(),  null, "Toggle navigation mesh")
}

showPointAction.subscribe(@(_) toolBoxComponent.redraw())
namePointAction.subscribe(@(_) toolBoxComponent.redraw())

propPanelVisible.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  if (v && getEditMode() != DE4_MODE_POINT_ACTION)
    toolboxShown.set(false)
})

return {
  toolboxShown
  toolboxButton = mkPanelElemsButton("Toolbox", @() toolboxShown.modify(@(v) !v))
  toolboxPopup = toolBoxComponent.panel

  setToolboxPopupPos

  addToolboxOption
  addToolboxOptions_CollGeomAndNavMesh
  clearToolboxOptions

  getToolboxState
  setToolboxState
  runToolboxCmd

  toolboxStyles = {
    buttonStyle = toolBoxComponent.buttonStyle
    buttonStyleOn = toolBoxComponent.buttonStyleOn
    buttonStyleOff = toolBoxComponent.buttonStyleOff
    rowDiv = toolBoxComponent.rowDiv
  }
}
