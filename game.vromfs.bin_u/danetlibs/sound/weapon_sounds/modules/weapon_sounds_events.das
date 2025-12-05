module weapon_sounds_events shared
require ecs

[cpp_event(unicast)]
struct CmdStartActionSfx
  targetEid : EntityId
  pos : float3
  norm : float3
  pmid : int

[event(broadcast)]
struct EventOnWeaponSound
  pos : float3
  isLoop : bool

[event(unicast)]
struct EventOnWizSound
  pos : float3
