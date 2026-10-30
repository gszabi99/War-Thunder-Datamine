local curLoginProcess = null

function destroyLoginProgress() {
  if (curLoginProcess)
    curLoginProcess.destroy()
  curLoginProcess = null
}

return freeze({
  getCurLoginProcess = @() curLoginProcess
  setCurLoginProcess = @(newLoginProcess) curLoginProcess = newLoginProcess
  destroyLoginProgress
})