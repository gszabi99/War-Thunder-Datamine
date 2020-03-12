local Rand = require("std/rand.nut")
local flex = ::flex
local hdpx = ::hdpx

local defParams = {num=30,emitter_sz=[hdpx(200),hdpx(100)], part=null}
local function baseParticles(params=defParams){
  local rand = Rand(params?.seed)
  local rnd_a = @(range) rand.rfloat(range[0],range[1])
  local function rnd2(range){
    local r = rnd_a(range)
    return [r,r]
  }
  local verbose = params?.debug ?? false
  local particles=[]
  local part = {transform={pivot=[0.5,0.5]}}.__merge(params?.part ?? {})
  local emitter_sz= params?.emitter_sz ?? defParams.emitter_sz
  local rotEndSpr = params?.rotEndSpr ?? 180
  local rotStartSpr = params?.rotStartSpr ?? 80
  local scaleEndRange = params?.scaleTo ?? [1.2,0.8]
  local scaleStartRange = params?.scaleTo ?? [0.5,0.8]
  local duration = params?.duration ?? [0.5,1.5]
  local key = params?.key ?? rand._seed
  local numParams = params?.num ?? defParams.num
  local emitterParams = params?.emitterParams ?? {}
  for (local i=0; i<numParams; i++) {
    local scaleTo = rnd2(scaleEndRange)
    local partW = part?.size[0] ?? hdpx(10)
    local partH = part?.size[1] ?? hdpx(10)
    local partMax = ::min(partH,partW)*2/3
    local partMin = ::max(partH,partW)/3
    local posTo = [rnd_a([0-partMin,emitter_sz[0]-partMax]), rnd_a([0-partMin,emitter_sz[1]-partMax])]
    local rotateTo = rnd_a([-rotEndSpr,rotEndSpr])
    local animations = [
      { prop=AnimProp.scale, from=rnd2(scaleStartRange), to=scaleTo, duration=rnd_a(duration), play=true, easing=OutCubic }
      { prop=AnimProp.rotate, from=rnd_a([-rotStartSpr,rotStartSpr])+rotateTo, to=rotateTo, duration=rnd_a(duration), play=true, easing=OutCubic}
      { prop=AnimProp.translate, from=[emitter_sz[0]/2,emitter_sz[1]/2], to=posTo, duration=rnd_a(duration), play=true, easing=OutCubic }
    ]

    local p = part.__merge({
      transform = {
        scale = scaleTo
        rotate = rotateTo
        translate = posTo
      }
      animations=animations
      key = key
    })
    particles.append(p)
  }
  if (verbose)
    particles.append(
      {rendObj=ROBJ_FRAME size=flex()}
      {rendObj=ROBJ_SOLID size=[1,8] hplace=ALIGN_CENTER vplace=ALIGN_CENTER}
      {rendObj=ROBJ_SOLID size=[8,1] hplace=ALIGN_CENTER vplace=ALIGN_CENTER}
    )
  return emitterParams.__merge({
    size = emitter_sz
    key = key
    children = particles
  })
}

return {
  baseParticles = baseParticles
}