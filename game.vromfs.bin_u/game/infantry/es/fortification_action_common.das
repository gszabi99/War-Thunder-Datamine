module fortification_action_common shared

require ecs

def test_segment_sphere_intersection_nonblocking(p0 : float3;
                                                 p1 : float3;
                                                 sphere_center : float3;
                                                 squared_sphere_radius : float)
  let oc = sphere_center - p0

  let l2oc = dot(oc, oc)
  var rsqr = squared_sphere_radius
  if (rsqr > l2oc) 
    rsqr = l2oc * 0.45

  let dir = p1 - p0
  let tca = dot(oc, dir)
  if tca <= 0.0
    return false 

  let dir2 = dot(dir, dir)
  let tca2 = (tca * tca) / dir2
  let l2hc = rsqr - l2oc + tca2
  if l2hc < 0.0
    return false 

  if tca2 + l2hc - 2.0 * sqrt(tca2 * l2hc) > dir2
    return false 

  return true
