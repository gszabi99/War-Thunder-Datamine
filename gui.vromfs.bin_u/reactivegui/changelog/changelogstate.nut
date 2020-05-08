const pathprefix = "scripts/changelog/changelogs/"
local langFile = @(version, lang) "{0}{1}_{2}.nut".subst(pathprefix,"_".join(version), lang)

local versions = ::Watched(::cross_call.changelog.getVersions() ?? [])
local unseenPatchnote = ::Watched(::cross_call.changelog.getUnseenPatchnote())
local languageName = ::Watched(::cross_call.language.getLanguageName() ?? "")

local function updatePatchnoteStates(config) {
  versions(config?.versions ?? versions.value)
  languageName(config?.languageName ?? languageName.value)
  if ("unseenPatchnote" in config)
    unseenPatchnote(config.unseenPatchnote)
}
::interop.updatePatchnoteStates <-  updatePatchnoteStates

local chosenPatchnote = ::Watched(null)
local curPatchnote = ::Computed(@() chosenPatchnote.value ?? unseenPatchnote.value ?? versions.value?[0])
local curPatchnoteIdx = ::Computed(@() versions.value.findindex(@(v) v.iVersion == curPatchnote.value?.iVersion) ?? 0)

local function choosePatchnote(version) {
  ::cross_call.changelog.markSeenVersion(curPatchnote.value)
  chosenPatchnote(version)
}

local function isVersion(version){
  return ::type(version?.version) == "array" && type(version?.iVersion) == "integer" && type(version?.tVersion) == "string"
}

local curVersionInfo = ::Computed(function(){
  local curPatch = curPatchnote.value
  if (!isVersion(curPatch))
    return null
  local res
  try {
    res = require_optional(langFile(curPatch.version, languageName.value.tolower())) ?? require_optional(langFile(curPatch.version, "en"))
  }
  catch(e){
    dlog("Some errors happened during loading update info")
  }
  return res
})

local function changePatchNote(delta=1){
  return function() {
    local nextIdx = clamp(curPatchnoteIdx.value-delta, 0, versions.value.len()-1)
    chosenPatchnote(versions.value[nextIdx])
  }
}
local nextPatchNote = changePatchNote()
local prevPatchNote = changePatchNote(-1)

return {
  choosePatchnote = choosePatchnote
  curPatchnote = curPatchnote
  versions = versions
  curVersionInfo = curVersionInfo
  curPatchnoteIdx = curPatchnoteIdx
  nextPatchNote = nextPatchNote
  prevPatchNote = prevPatchNote
}
