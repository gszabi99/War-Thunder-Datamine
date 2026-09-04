let webBrowser = require_optional("webBrowser")
let consttable = getconsttable()

let fields = [
  "BROWSER_EVENT_DOCUMENT_READY",
  "BROWSER_EVENT_FAIL_LOADING_FRAME",
  "BROWSER_EVENT_CANT_DOWNLOAD",
  "BROWSER_EVENT_FINISH_LOADING_FRAME",
  "BROWSER_EVENT_BEGIN_LOADING_FRAME",
  "BROWSER_EVENT_NEED_RESEND_FRAME",
  "BROWSER_EVENT_BROWSER_CRASHED",
]

let export = {}
foreach (k in fields)
  export[k] <- webBrowser?[k] ?? consttable[k]

return freeze(export)
