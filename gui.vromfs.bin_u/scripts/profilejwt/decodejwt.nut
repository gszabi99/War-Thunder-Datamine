import "%scripts/profileJwt/profilePublicKey.nut" as profilePublicKey
from "jwt" import decode

function decodeJwtAndHandleErrors(jwt) {
  if (jwt == null)
    return { decodError = "jwt is null" }
  let jwtDecoded = decode(jwt, profilePublicKey)

  let { payload = null } = jwtDecoded
  let jwtError = jwtDecoded?.error
  if (payload != null && jwtError == null)
    return { jwt, payload }

  return { decodError = jwtError }
}

return freeze({
  decodeJwtAndHandleErrors
})