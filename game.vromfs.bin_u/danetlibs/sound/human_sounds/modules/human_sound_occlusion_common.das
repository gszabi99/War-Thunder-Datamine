module human_sound_occlusion_common shared

require ecs
require soundEvent


def attach_to_gun_owner_blob(handle : auto&; gun__owner : EntityId; turret__owner : EntityId; gun_blob : SoundOcclusionBlob&)
  if turret__owner != INVALID_ENTITY_ID
    attach_to_blob(handle, gun_blob)
    return
  var attached = false
  query(gun__owner) <| $ [es] (human_sound_occlusion__blob : SoundOcclusionBlob&)
    if is_valid_handle_value(human_sound_occlusion__blob)
      attach_to_blob(handle, human_sound_occlusion__blob)
      attached = true
  if !attached
    attach_to_blob(handle, gun_blob)
