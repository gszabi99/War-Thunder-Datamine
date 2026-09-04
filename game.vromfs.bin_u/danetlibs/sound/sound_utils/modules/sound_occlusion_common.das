options gen2
module sound_occlusion_common shared
require math
require math.base
require DagorMath

def prevent_wall_sound_occlusion(pos, norm : float3; offset = 0.15) { 
  return pos + norm * offset
}

def prevent_wall_sound_occlusion(pos, norm, listener : float3; offset = 0.15) {
  let nrm = dot(listener - pos, norm) > 0. ? norm : -norm
  return pos + nrm * offset
}

def prevent_self_occlusion(pos, listener : float3; radius : float; var offset : float3&) : float3 {
  offset = listener - pos
  let distSq = length_sq(offset)
  if (distSq > square(radius)) {
    offset = (offset / sqrt(distSq)) * radius
  }
  return pos + offset
}

def prevent_self_occlusion(pos, listener : float3; radius : float) : float3 {
  var offset : float3
  return prevent_self_occlusion(pos, listener, radius, offset)
}


def prevent_self_occlusion(occluder_pos, sound_pos, listener_pos : float3; occluder_radius, offset : float = 0.) : float3 {

  
  if (distance_sq(listener_pos, occluder_pos) <= square(occluder_radius))
    return sound_pos

  
  let isInside = distance_sq(sound_pos, occluder_pos) < square(occluder_radius)

  
  let listenerToSound = sound_pos - listener_pos
  let distSqListenerToSound = dot(listenerToSound, listenerToSound)
  if (distSqListenerToSound >= square(0.001))
    return sound_pos

  let distListenerToSound = sqrt(distSqListenerToSound)
  let dir = listenerToSound / distListenerToSound

  
  let oc = listener_pos - occluder_pos
  let b = dot(oc, dir)
  let c = dot(oc, oc) - square(occluder_radius)
  let discriminant = b * b - c
  if (!isInside && discriminant < 0.) 
    return sound_pos

  let sqrtD = discriminant > 0. ? sqrt(discriminant) : 0.
  
  let t1 = -b - sqrtD
  let t2 = -b + sqrtD

  if (!isInside && (t1 > distListenerToSound || t2 < 0.))
    return sound_pos

  let newT = max(t1 - max(offset, 0.), 0.0001)
  if (!isInside && newT >= distListenerToSound)
    return sound_pos

  return listener_pos + dir * newT
}
