import "%rGui/globals/extWatched.nut" as extWatched


let isSpectatorMode = extWatched("isSpectatorMode", false) 
let isDedicatedSpectator = extWatched("isDedicatedSpectator", false) 

return freeze({
  isSpectatorMode
  isDedicatedSpectator
})
