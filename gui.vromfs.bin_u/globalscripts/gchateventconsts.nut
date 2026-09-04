let chat = require_optional("chat")
let consttable = getconsttable()

let fields = [
  "GCHAT_EVENT_CONNECTED",
  "GCHAT_EVENT_DISCONNECTED",
  "GCHAT_EVENT_CONNECTION_FAILURE",
  "GCHAT_EVENT_MESSAGE",
  "GCHAT_EVENT_TASK_RESPONSE",
  "GCHAT_EVENT_TASK_ERROR",
  "GCHAT_EVENT_VOICE",
]

let export = {}
foreach (k in fields)
  export[k] <- chat?[k] ?? consttable[k]

return freeze(export)
