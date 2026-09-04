let yuplay2 = require_optional("yuplay2")
let consttable = getconsttable()

let fields = [
  "YU2_OK",
  "YU2_BUSY",
  "YU2_WRONG_PARAMETER",
  "YU2_WRONG_LOGIN",
  "YU2_NOT_LOGGED_IN",
  "YU2_EMPTY",
  "YU2_ALREADY",
  "YU2_NOT_FOUND",
  "YU2_FORBIDDEN",
  "YU2_EXPIRED",
  "YU2_NO_MONEY",
  "YU2_UNKNOWN",
  "YU2_FAIL",
  "YU2_FROZEN",
  "YU2_FROZEN_BRUTEFORCE",
  "YU2_NOT_OWNER",
  "YU2_PSN_UNKNOWN",
  "YU2_PSN_RESTRICTED",
  "YU2_2STEP_AUTH",
  "YU2_TIMEOUT",
  "YU2_HOST_RESOLVE",
  "YU2_SSL_CACERT",
  "YU2_SSL_CACERT_FILE",
  "YU2_SSL_ERROR",
  "YU2_PROFILE_DELETED",
  "YU2_WRONG_PAYMENT",
  "YU2_WRONG_2STEP_CODE",
  "YU2_PAYMENT_LIMIT",
  "YU2_BAD_DOMAIN",
  "YU2_WRONG_EMAIL",
  "YU2_DOI_INCOMPLETE",
  "YU2_FORBIDDEN_NEED_2STEP",

  "YU2_PAY_NONE",
  "YU2_PAY_QIWI",
  "YU2_PAY_YANDEX",
  "YU2_PAY_PAYPAL",
  "YU2_PAY_WEBMONEY",
  "YU2_PAY_AMAZON",
  "YU2_PAY_GJN",
]

let export = {}
foreach (k in fields)
  export[k] <- yuplay2?[k] ?? consttable[k]

return freeze(export)
