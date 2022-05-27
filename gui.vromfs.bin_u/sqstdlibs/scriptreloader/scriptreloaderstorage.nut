::ScriptReloaderStorage <- class
{
  contextWeak = null
  paramsArray = null
  storedData = null

  constructor(context, paramsList)
  {
    setContextParams(context, paramsList)
  }

  function setContextParams(context, paramsList)
  {
    contextWeak = context ? context.weakref() : null
    paramsArray = paramsList
  }

  function switchToNewContext(context, paramsList)
  {
    setContextParams(context, paramsList)
    loadDataFromStorage()
  }

  function loadDataFromStorage()
  {
    if (!storedData || !paramsArray || !contextWeak)
      return

    foreach(param in paramsArray)
      if ((param in contextWeak) && (param in storedData))
        contextWeak[param] = storedData[param]
  }

  function saveDataToStorage()
  {
    if (!contextWeak)
      return

    if (!storedData)
      storedData = {}

    foreach(param in paramsArray)
      if (param in contextWeak)
        storedData[param] <- contextWeak[param]
  }
}