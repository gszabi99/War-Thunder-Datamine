from "%darg/ui_imports.nut" import *
from "%darg/laconic.nut" import *
let { addModalWindow, removeModalWindow } = require("%daeditor/components/modalWindows.nut")
let { makeVertScroll } = require("%daeditor/components/scrollbar.nut")
let textButton = require("components/textButton.nut")
let {get_arg_value_by_name} = require("dagor.system")
let nameFilter = require("components/nameFilter.nut")
let { colors } = require("components/style.nut")
let {scan_folder, mkpath, file_exists} = require("dagor.fs")
let textInput = require("%daeditor/components/textInput.nut")
let datablock = require("DataBlock")

const imporSceneUID = "import_scene_modal_window"
const sceneSubDir = "gamedata/scenes"

let isNewImportMode = Watched(false)
let filterImportString = mkWatched(persist, "filterImportString", "")
let selectedImport = Watched("")

let gamebase = get_arg_value_by_name("gamebase")
let root = gamebase != null ? $"{gamebase}/" : ""

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

function mkTabButtons() {
  return @() {
    watch = [isNewImportMode]
    flow = FLOW_HORIZONTAL
    gap = fsh(0.25)
    children = [
      {
        rendObj = ROBJ_BOX
        size = SIZE_TO_CONTENT
        behavior = Behaviors.Button
        onClick = @() isNewImportMode.set(false)
        fillColor = !isNewImportMode.get() ? Color(80, 80, 85) : Color(65, 65, 70)
        children = {
          margin = [hdpx(2), hdpx(4)]
          rendObj = ROBJ_TEXT
          text = "Load existing"
        }
      }
      {
        rendObj = ROBJ_BOX
        size = SIZE_TO_CONTENT
        fillColor = isNewImportMode.get() ? Color(80, 80, 85) : Color(65, 65, 70)
        behavior = Behaviors.Button
        onClick = @() isNewImportMode.set(true)
        children = {
          margin = [hdpx(2), hdpx(4)]
          rendObj = ROBJ_TEXT
          text = "Create new"
        }
      }
    ]
  }
}

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

function mkAcceptSceneControl(onImportAdd, close) {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    children = [
      @(){
        valign = ALIGN_CENTER
        rendObj = ROBJ_TEXT
        size = flex()
        watch = selectedImport
        text = selectedImport.get() == "" ? $"{sceneSubDir}/<scene_name_placeholder>.blk" : $"{selectedImport.get()}"
        color = colors.TextDefault
      }
      @() {
        size = SIZE_TO_CONTENT
        valign = ALIGN_CENTER
        halign = ALIGN_RIGHT
        watch = [selectedImport]
        children = textButton("Add scene", function() {
          onImportAdd(selectedImport.get())
          close()
          },
          {
            boxStyle = {
              normal = {
                margin = 0
              }
          }
          off = selectedImport.get() == "",
          disabled = Computed(@() selectedImport.get() == "")
          })
        }
    ]
  }
}

function mkExistinTabContent(onImportAdd, close) {
  let scenes = scan_folder({ root = $"{root}{sceneSubDir}", vromfs = true, realfs = true, recursive = true, files_suffix = "*.blk" })
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

  return {
    size = flex()
    flow = FLOW_VERTICAL
    children = [
      {
        padding = hdpx(10)
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = fsh(0.5)
        children = [
          addImportFilter
          mkAcceptSceneControl(onImportAdd, close)
          {
            rendObj = ROBJ_TEXT
            size = [flex(), SIZE_TO_CONTENT]
            text = "Select a scene to import"
            color = colors.TextReadOnly
          }
        ]
      }
      makeVertScroll(listImportContent)
    ]
  }
}

function mkNewTabContent(onImportAdd, close) {
  let newSceneName = Watched("")
  let isSceneValid = Computed(@() newSceneName.get()!=null && newSceneName.get()!="" && !file_exists($"%gameBase/{sceneSubDir}{newSceneName.get()}.blk"))

  return {
    size = flex()
    flow = FLOW_VERTICAL
    children = [
      {
        padding = hdpx(10)
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = fsh(0.5)
        children = [
          textInput(newSceneName, {
            placeholder = "Input scene name"
            textmargin = fsh(0.5)
            margin = 0
            size = FLEX_H
            valignText = ALIGN_CENTER
            colors = {
              backGroundColor = colors.ControlBg
              placeHolderColor = Color(160, 160, 160)
            }
          })
          {
            size = [flex(), SIZE_TO_CONTENT]
            flow = FLOW_HORIZONTAL
            children = [
              @() {
                rendObj = ROBJ_TEXT
                size = flex()
                valign = ALIGN_CENTER
                watch = newSceneName
                text = newSceneName.get() == "" ? $"{sceneSubDir}/<scene_name_placeholder>.blk" : $"{sceneSubDir}/{newSceneName.get()}.blk"
                color = colors.TextDefault
              }
              @() {
                watch = isSceneValid
                size = SIZE_TO_CONTENT
                children = textButton("Create and add", function() {
                  let path = $"{sceneSubDir}/{newSceneName.get()}.blk"
                  mkpath($"%gameBase/{path}")
                  let data = datablock()
                  data.saveToTextFile($"%gameBase/{path}");
                  onImportAdd(path)
                  close()
                  }, { off = !isSceneValid.get(), disabled = Computed(@() !isSceneValid.get()) })
              }
            ]
          }
        ]
      }
      {
        size = flex()
      }
    ]
  }
}

function addImportDialog(onImportAdd) {
  let close = function() {
    selectedImport.set("")
    removeModalWindow(imporSceneUID)
  }

  addModalWindow({
    key = imporSceneUID
    children =
    @(){
      behavior = Behaviors.Button
      flow = FLOW_VERTICAL
      rendObj = ROBJ_SOLID
      size = const [hdpx(800), hdpx(768)]
      color = Color(20,20,20,255)
      padding = hdpx(10)
      watch = [isNewImportMode]
      children = [
        mkTabButtons()
        {
          rendObj = ROBJ_BOX
          size = flex()
          borderColor = Color(80, 80, 85)
          borderWidth = hdpx(4)
          padding = hdpx(4)
          children = isNewImportMode.get() ? mkNewTabContent(onImportAdd, close) : mkExistinTabContent(onImportAdd, close)
        }
        {
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          size = [flex(), SIZE_TO_CONTENT]
          padding = hdpx(10)
          children = textButton("Cancel", close, {
            hotkeys=[["Esc"]],
            boxStyle = {
              normal = {
                margin = 0
              }
            }
          })
        }
      ]
    }
  })
}

return {
  addImportDialog
}
