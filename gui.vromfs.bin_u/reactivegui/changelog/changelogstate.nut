local extWatched = require("reactiveGui/globals/extWatched.nut")

local versions = extWatched("changelogsVersions", ::cross_call.changelog.getVersions)
local chosenPatchnoteContent = extWatched("chosenPatchnoteContent",
  ::cross_call.changelog.getChosenPatchnoteContent)
local chosenPatchnoteLoaded = extWatched("chosenPatchnoteLoaded",
  ::cross_call.changelog.getChosenPatchnoteLoaded)
local patchnotesReceived = extWatched("patchnotesReceived",
  ::cross_call.changelog.getPatchnotesReceived)
local curPatchnote = extWatched("curPatchnote", ::cross_call.changelog.getCurPatchnote)
local curPatchnoteIdx = extWatched("curPatchnoteIdx", ::cross_call.changelog.getCurPatchnoteIdx)

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
