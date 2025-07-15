from "%rGui/globals/ui_library.nut" import *

let loadedDasScripts = {}

function getDasScriptByPath(scriptPath) {
  if (scriptPath not in loadedDasScripts)
    loadedDasScripts[scriptPath] <- load_das(scriptPath)

  return loadedDasScripts[scriptPath]
}

return {
  getDasScriptByPath
}
