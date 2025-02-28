from "%scripts/dagui_library.nut" import *

let queueClasses = {}

function registerQueueClass(key, queueClass) {
  if (key in queueClasses) {
    logerr($"[Queue] queueClasses already has {key} class")
    return
  }
  queueClasses[key] <- queueClass
}

let getQueueClass = @(key) queueClasses?[key]

return {
  registerQueueClass
  getQueueClass
}