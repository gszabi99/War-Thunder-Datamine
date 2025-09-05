from "%scripts/dagui_library.nut" import *
let inventory = require("inventory")
let { is_xbox } = require("%sqstd/platform.nut")

let keys = [
@"
-----BEGIN PUBLIC KEY-----
MIIBKDANBgkqhkiG9w0BAQEFAAOCARUAMIIBEAKCAQcAy9WagPn8/uLbbPHebobA
ftDiwrGpi23Ed0fQsSCZfGYupBkYl3mZD3fgOMgmLSYsTqFHDe0CMTQKpHYGFfT3
EuvTHKwwyo2ckpaLNI/flZysDXRuoWXvwd6FzGBx3l2/I1Yw+cAle/aWB9YZnQtX
fy3j3k/fJfiv7+72Sm95h3Dg715XuBILC4vSYVqvCn+UlQyrJkAZrIahWR9Gzsm6
ovxSaduvosn83Hx1ZixD+U5wcn1hoTT0niwnrqiPuEUV3wC887JIR4KzMXYpyzvF
nEhlqTKoGN7oGS7vqN4tCH6/l3hAomxfVGT+5UHGugQEauNqccYq44Hfu3t3tY1r
j+eTYc35NQIDAQAB
-----END PUBLIC KEY-----
"
]

function initPublicKeys() {
  if (is_xbox) {
    log("Content signature verification temporary disabled for xboxone")
    return false
  }

  foreach (key in keys)
    inventory.addContentPublicKey(key)

  return true
}

return {
  keys = keys
  initialized = initPublicKeys()
}
