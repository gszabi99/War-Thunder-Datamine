import "%globalScripts/sharedWatched.nut" as sharedWatched


let controlledHeroEid = sharedWatched("controlledHeroEid", @() 0)

return freeze({
  controlledHeroEid
})