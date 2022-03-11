let extWatched = require("reactiveGui/globals/extWatched.nut")

let versions = extWatched("changelogsVersions", ::cross_call.changelog.getVersions)
let chosenPatchnoteContent = extWatched("chosenPatchnoteContent",
  ::cross_call.changelog.getChosenPatchnoteContent)
let chosenPatchnoteLoaded = extWatched("chosenPatchnoteLoaded",
  ::cross_call.changelog.getChosenPatchnoteLoaded)
let patchnotesReceived = extWatched("patchnotesReceived",
  ::cross_call.changelog.getPatchnotesReceived)
let curPatchnote = extWatched("curPatchnote", ::cross_call.changelog.getCurPatchnote)
let curPatchnoteIdx = extWatched("curPatchnoteIdx", ::cross_call.changelog.getCurPatchnoteIdx)

return {
  versions
  curPatchnote
  curPatchnoteIdx
  chosenPatchnoteContent
  chosenPatchnoteLoaded
  patchnotesReceived
  nextPatchNote = @() ::cross_call.changelog.changePatchNote()
  prevPatchNote = @() ::cross_call.changelog.changePatchNote(-1)
  choosePatchnote = @(v) ::cross_call.changelog.choosePatchnote(v)
}
