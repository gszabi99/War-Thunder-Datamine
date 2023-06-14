
let ScriptReloaderStorage = class {
  contextWeak = null
  paramsArray = null
  storedData = null

  constructor(context, paramsList) {
    this.setContextParams(context, paramsList)
  }

  function setContextParams(context, paramsList) {
    this.contextWeak = context ? context.weakref() : null
    this.paramsArray = paramsList
  }

  function switchToNewContext(context, paramsList) {
    this.setContextParams(context, paramsList)
    this.loadDataFromStorage()
  }

  function loadDataFromStorage() {
    if (!this.storedData || !this.paramsArray || !this.contextWeak)
      return

    foreach(param in this.paramsArray)
      if ((param in this.contextWeak) && (param in this.storedData))
        this.contextWeak[param] = this.storedData[param]
  }

  function saveDataToStorage() {
    if (!this.contextWeak)
      return

    if (!this.storedData)
      this.storedData = {}

    foreach(param in this.paramsArray)
      if (param in this.contextWeak)
        this.storedData[param] <- this.contextWeak[param]
  }
}
return {
  ScriptReloaderStorage
}