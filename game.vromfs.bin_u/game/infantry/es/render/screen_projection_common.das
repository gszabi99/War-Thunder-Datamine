module screen_projection_common shared


def from_world_coord_to_screen(worldPos : float3; wk : float; hk : float; screenHalfSize : float2)
  return float2(worldPos.x / worldPos.z * wk * screenHalfSize.x, -worldPos.y / worldPos.z * hk * screenHalfSize.y) + screenHalfSize
