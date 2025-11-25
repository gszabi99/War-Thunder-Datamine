from "%rGui/globals/ui_library.nut" import *
let { subscribe, send } = require("eventbus")
let extWatched = require("%rGui/globals/extWatched.nut")

let versions = mkWatched(persist, "versions", [])
let chosenPatchnoteContent = mkWatched(persist, "chosenPatchnoteContent", { title = "", text = "" })
let chosenPatchnoteLoaded = mkWatched(persist, "chosenPatchnoteLoaded", false)
let patchnotesReceived = mkWatched(persist, "patchnotesReceived", false)
let curPatchnote = mkWatched(persist, "curPatchnote", null)
let curPatchnoteIdx = Computed(
  @() versions.get().findindex(@(inst) inst.id == curPatchnote.get()?.id) ?? 0)
let hasReviewBtnForCurPatchnote = Computed(@() curPatchnote.get()?.customData.showReviewBtn ?? false)
let canShowSteamReviewBtn = extWatched("canShowSteamReviewBtn", false)
let isNews = mkWatched(persist, "isNews", false)
let isEvent = mkWatched(persist, "isEvent", false)
let needShowSteamReviewBtn = Computed(@() hasReviewBtnForCurPatchnote.get()
  && canShowSteamReviewBtn.get() && !isNews.get() && !isEvent.get())

subscribe("updateChosenPatchnoteContent", @(data) chosenPatchnoteContent.set(data.value))
subscribe("updateChangelogsVersions", @(data) versions.set(data.value))
subscribe("updateChangelogsIsNews", @(data) isNews.set(data.value))
subscribe("updateChangelogsIsEvent", @(data) isEvent.set(data.value))
subscribe("updateCurPatchnote", @(data) curPatchnote.set(data.value))
subscribe("updateChosenPatchnoteLoaded", @(data) chosenPatchnoteLoaded.set(data.value))
subscribe("updatePatchnotesReceived", @(data) patchnotesReceived.set(data.value))

subscribe("updateChangeLogsStates", function(data) {
  versions.set(data.versions)
  chosenPatchnoteContent.set(data.chosenPatchnoteContent)
  chosenPatchnoteLoaded.set(data.chosenPatchnoteLoaded)
  patchnotesReceived.set(data.patchnotesReceived)
  curPatchnote.set(data.curPatchnote)
  isNews.set(data.isNews)
  isEvent.set(data.isEvent)
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
  closePatchnote = @() send("closePatchnote", {})
  needShowSteamReviewBtn
  isNews
  isEvent
}
