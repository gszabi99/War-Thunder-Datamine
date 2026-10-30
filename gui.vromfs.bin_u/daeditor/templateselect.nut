import "daEditorEmbedded" as daEditor
from "%darg/ui_imports.nut" import *

let entity_editor = require_optional("entity_editor")
let { editorIsActive, showDebugButtons, selectedTemplatesGroup, addEntityCreatedCallback } = require("state.nut")
let { allModifiableScenes, sceneToComboboxEntry } = require("sceneModel.nut")
let { colors } = require("components/style.nut")
let txt = require("%daeditor/components/text.nut").dtext

let textButton = require("components/textButton.nut")
let closeButton = require("components/closeButton.nut")
let combobox = require("%daeditor/components/combobox.nut")
let { mkFilteredList, mkListFilter, rowText } = require("components/mkFilteredList.nut")
let { mkTemplateTooltip } = require("components/templateHelp.nut")

let {DE4_MODE_SELECT} = daEditor

const noSceneSelected = "UNKNOWN:0"
let allSceneTexts = Computed(@() allModifiableScenes.get().map(@(scene, _idx) sceneToComboboxEntry(scene)).append(noSceneSelected))
let selectedScene = Watched(noSceneSelected)
let selectedItem = Watched(null)
let filterText = Watched("")
let templatePostfixText = Watched("")

addEntityCreatedCallback(@(_eid) set_kb_focus(null))

function doSelectTemplate(tpl_name) {
  selectedItem.set(tpl_name)
  if (selectedItem.get()) {
    let finalTemplateName = selectedItem.get() + templatePostfixText.get()
    entity_editor?.get_instance().selectEcsTemplate(finalTemplateName)
  }
}

let filter = mkListFilter(filterText, { onAttach = @(elem) set_kb_focus(elem) })
let templPostfix = mkListFilter(templatePostfixText, { placeholder = "Template postfix" })

let templateTooltip = Watched(null)

let selectedGroupTemplates = Computed(@() editorIsActive.get()
  ? entity_editor?.get_instance().getEcsTemplates(selectedTemplatesGroup.get()) ?? [] : [])

let filteredTemplates = Computed(function() {
  let result = []
  foreach (tplName in selectedGroupTemplates.get()) {
    if (filterText.get().len()==0 || tplName.tolower().contains(filterText.get().tolower())) {
      result.append(tplName)
    }
  }
  return result
})

let filteredTemplatesCount = Computed(@() filteredTemplates.get().len())
let selectedGroupTemplatesCount = Computed(@() selectedGroupTemplates.get().len())

let templatesList = mkFilteredList({
  items = filteredTemplates
  selected = selectedItem
  mkRow = @(tplName, _row) rowText(tplName)
  onClick = @(tplName, _evt) doSelectTemplate(tplName)
  onHover = @(tplName, on) templateTooltip.set(on ? mkTemplateTooltip(tplName) : null)
})


local doRepeatValidateTemplates = @(_idx) null
function doValidateTemplates(idx) {
  const validateAfterName = ""
  local skipped = 0
  while (idx < selectedGroupTemplates.get().len()) {
    let tplName = selectedGroupTemplates.get()[idx]
    if (tplName > validateAfterName) {
      vlog($"Validating template {tplName}...")
      selectedItem.set(tplName)
      gui_scene.resetTimeout(0.01, function() {
        doSelectTemplate(tplName)
        doRepeatValidateTemplates(idx+1)
      })
      return
    }
    vlog($"Skipping template {tplName}...")
    if (++skipped > 50) {
      selectedItem.set(tplName)
      gui_scene.resetTimeout(0.01, @() doRepeatValidateTemplates(idx+1))
      return
    }
    idx += 1
  }
  vlog("Validation complete")
}
doRepeatValidateTemplates = doValidateTemplates

function syncSelectedScene(_v) {
  local scene = entity_editor?.get_instance()?.getTargetScene()
  let sceneText = (scene != null && ("loadType" in scene) && ("id" in scene)) ? sceneToComboboxEntry(scene) : null
  if (sceneText != null && allSceneTexts.get().contains(sceneText)) {
    selectedScene.set(sceneText)
  } else {
    selectedScene.set(noSceneSelected)
  }
}

function dialogRoot() {
  let templatesGroups = entity_editor?.get_instance().getEcsTemplatesGroups()

  let selectedSceneIndex = selectedScene.get() != noSceneSelected ? allSceneTexts.get().indexof(selectedScene.get()) : null
  let sceneInfo = selectedSceneIndex != null ? allModifiableScenes.get()[selectedSceneIndex] : null
  let sceneTitleStyle = { fontSize = hdpx(17), color=Color(150,150,150,120) }
  let sceneInfoStyle = { fontSize = hdpx(17), color=Color(180,180,180,120) }
  let sceneTooltip = @() {
    rendObj = ROBJ_BOX
    fillColor = Color(30, 30, 30, 220)
    borderColor = Color(50, 50, 50, 110)
    size = SIZE_TO_CONTENT
    borderWidth = hdpx(1)
    padding = fsh(1)
    flow = FLOW_VERTICAL
    children = [
      txt("Select target scene to create entity in", sceneTitleStyle)
      txt(selectedScene.get(), sceneInfoStyle)
      sceneInfo != null ? txt($"{sceneInfo.path}", sceneInfoStyle) : null
    ]
  }

  function doClose() {
    filterText.set("")
    daEditor.setEditMode(DE4_MODE_SELECT)
  }

  function doCancel() {
    if (selectedItem.get() != null) {
      selectedItem.set(null)
      entity_editor?.get_instance().selectEcsTemplate("")
    }
    else
      doClose()
  }

  return {
    size = const [flex(), flex()]
    flow = FLOW_HORIZONTAL

    watch = [filteredTemplatesCount, selectedGroupTemplatesCount, showDebugButtons, templateTooltip, selectedScene, allModifiableScenes]
    
    onAttach = function() {
      syncSelectedScene(null)
      allModifiableScenes.subscribe_with_nasty_disregard_of_frp_update(syncSelectedScene)
    }
    onDetach = @() allModifiableScenes.unsubscribe(syncSelectedScene)

    children = [
      {
        size = const [sw(17), sh(75)]
        hplace = ALIGN_LEFT
        vplace = ALIGN_CENTER
        rendObj = ROBJ_SOLID
        color = colors.ControlBg
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        behavior = Behaviors.Button
        key = "template_select"
        padding = fsh(0.5)
        gap = fsh(0.5)

        children = [
          {
            flow = FLOW_HORIZONTAL
            size = FLEX_H
            children = [
              txt($"CREATE ENTITY ({filteredTemplatesCount.get()}/{selectedGroupTemplatesCount.get()})", {
                fontSize = hdpx(15)
                hplace = ALIGN_CENTER
                vplace = ALIGN_CENTER
                size = FLEX_H
              })
              closeButton(doClose)
            ]
          }
          {
            size = const [flex(),fontH(100)]
            children = combobox({
              value = selectedScene
              
              changeVarOnListUpdate = false
              update = function(v) {
                local id = -1
                if (v != noSceneSelected) {
                  local selectedBoxItem = allSceneTexts.get().indexof(v)
                  if (selectedBoxItem != null) {
                    local scene = allModifiableScenes.get()[selectedBoxItem]
                    id = scene.id
                  }
                }
                entity_editor?.get_instance().setTargetScene(id)
                selectedScene.set(v)
              }
            }, allSceneTexts, sceneTooltip)
          }

          {
            size = const [flex(),fontH(100)]
            children = combobox(selectedTemplatesGroup, templatesGroups)
          }
          filter
          templatesList
          templPostfix
          {
            flow = FLOW_HORIZONTAL
            size = FLEX_H
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            hotkeys = [["^Esc", doCancel]]
            children = [
              textButton("Close", doClose)
              showDebugButtons.get() ? textButton("Validate", @() doValidateTemplates(0), {boxStyle={normal={borderColor=Color(50,50,50,50)}} textStyle={normal={color=Color(80,80,80,80) fontSize=hdpx(12)}}}) : null
            ]
          }
        ]
      }
      {
        size = const [sw(17), sh(60)]
        hplace = ALIGN_LEFT
        vplace = ALIGN_CENTER
        children = templateTooltip.get()
      }
    ]
  }
}


return dialogRoot
