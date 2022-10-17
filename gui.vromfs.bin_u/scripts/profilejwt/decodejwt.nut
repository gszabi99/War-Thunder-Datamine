//checked for explicitness
#no-root-fallback
#explicit-this

let { decode } = require("jwt")
let profilePublicKey = require("%scripts/profileJwt/profilePublicKey.nut")

let function decodeJwtAndHandleErrors(jwt) {
  let jwtDecoded = decode(jwt, profilePublicKey)

  let { payload = null } = jwtDecoded
  let jwtError = jwtDecoded?.error
  if (payload != null && jwtError == null)
    return { jwt, payload }

  return { error = jwtError }
}

return {
  decodeJwtAndHandleErrors
}