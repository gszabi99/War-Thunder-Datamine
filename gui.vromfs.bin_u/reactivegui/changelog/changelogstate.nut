from "%rGui/globals/ui_library.nut" import *
let { subscribe, send } = require("eventbus")

let versions = mkWatched(persist, "versions", [])
let chosenPatchnoteContent = mkWatched(persist, "chosenPatchnoteContent", { title = "", text = "" })
let chosenPatchnoteLoaded = mkWatched(persist, "chosenPatchnoteLoaded", false)
let patchnotesReceived = mkWatched(persist, "patchnotesReceived", false)
let curPatchnote = mkWatched(persist, "curPatchnote", null)
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
