from "%rGui/globals/ui_library.nut" import *
let { subscribe, send } = require("eventbus")

let versions = persist("versions", @() Watched([]))
let chosenPatchnoteContent = persist("chosenPatchnoteContent",
  @() Watched({title = "", text = ""}))
let chosenPatchnoteLoaded = persist("chosenPatchnoteLoaded", @() Watched(false))
let patchnotesReceived = persist("patchnotesReceived", @() Watched(false))
let curPatchnote = persist("curPatchnote", @() Watched(null))
let curPatchnoteIdx = Computed(
  @() versions.value.findindex(@(inst) inst.id == curPatchnote.value?.id) ?? 0)


subscribe("updateChosenPatchnoteContent", @(data) chosenPatchnoteContent(data.value))
subscribe("updateChangelogsVersions", @(data) versions(data.value))
subscribe("updateCurPatchnote", @(data) curPatchnote(data.value))
subscribe("updateChosenPatchnoteLoaded", @(data) chosenPatchnoteLoaded(data.value))
subscribe("updatePatchnotesReceived", @(data) patchnotesReceived(data.value))

subscribe("updateChangeLogsStates", function(data) {
  versions(data.versions)
  chosenPatchnoteContent(data.chosenPatchnoteContent)
  chosenPatchnoteLoaded(data.chosenPatchnoteLoaded)
  patchnotesReceived(data.patchnotesReceived)
  curPatchnote(data.curPatchnote)
})

send("getChangeLogsStates", {})

return {
  versions
  curPatchnote
  curPatchnoteIdx
  chosenPatchnoteContent
  chosenPatchnoteLoaded
  patchnotesReceived
  nextPatchNote = @() send("changePatchNote", { delta = 1 })
  prevPatchNote = @() send("changePatchNote", { delta = -1 })
  choosePatchnote = @(value) send("choosePatchnote", { value })
}
