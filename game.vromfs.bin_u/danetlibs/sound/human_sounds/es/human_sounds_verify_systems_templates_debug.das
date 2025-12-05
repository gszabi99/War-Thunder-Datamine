options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require soundEvent
require DngHuman


[req_template]
struct HumanWithClimpSound
  sound_tags : ecs::Object
  sound_event_group : SoundEventGroup
  sound_paths : ecs::SharedObject
  is_watched_sound : bool
  human_net_phys__isClimbing : bool
  transform : float3x4


[req_template]
struct HumanIrqSound
  humanSound : ecs::Tag
  sound_event_group : SoundEventGroup
  sound_tags : ecs::Object
  sound_irqs : ecs::SharedObject
  is_watched_sound : bool
  transform : float3x4


[req_template]
struct HumanIrqSoundVoiceFx
  humanSound : ecs::Tag
  sound_event_group : SoundEventGroup
  human_voice_sound__path : SharedObject
  human_voice_sound__irqs : SharedObject
  sound_tags : ecs::Object
  is_watched_sound : bool
  transform : float3x4


[req_template]
struct HumanDeathSound
  human_voice_sound__path : SharedObject
  human_voice_sound__descs : SharedObject
  sound_event_group : SoundEventGroup
  sound_tags : ecs::Object
  transform : float3x4


[req_template]
struct HumanIdleSoundRequiredComponents
  sound_control__state : int
  sound_tags : Object
  is_watched_sound : bool
  transform : float3x4
  isAlive : bool
  isDowned : bool


[req_template]
struct HumanVoiceEffect
  human_voice_effect__type : string
  human_voice_effect__isActive : bool
  human_voice_effect__event : SoundEvent
  human_voice_sound__path : SharedObject
  human_voice_sound__descs : SharedObject
  sound_tags : Object
  transform : float3x4


[req_template]
struct HumanUnderwaterSound
  human_breath__isUnderWater : bool
  human_breath__timer : float
  human_breath__maxHoldBreathTime : float
  human_voice_effect__activeEffects : Object
  human_voice_effect__event : SoundEvent


[req_template]
struct HumanCollisionScrapeSound
  human_net_phys__velocity : float3
  human_collision_scrape_sound__descIdx : int
  human_collision_scrape_sound__descs : SharedArray
  human_collision_scrape_sound__speedToForce : float4
  sound_event_group : SoundEventGroup
  sound_tags : Object
  is_watched_sound : bool
  transform : float3x4


[es(on_event=VerifyEcsTemplates)]
def human_sounds_verify_ecs_templates(evt : Event)
  req_unique_event_handler("CmdSoundIrq")
  req_unique_event_handler("CmdSoundVoicefxIrq")

[req_template]
struct SoundLandmeshQueries
  is_watched_sound : bool
  transform : float3x4
  human_sound_landmesh_queries_vars__speedSq : float
  human_sound_landmesh_queries_vars__isOnGround : bool
  human_sound_landmesh_queries__lmeshDiff : float
  human_sound_landmesh_queries__farawayThreshold : float
  human_sound_landmesh_queries__heroSpeedToQueryInterval : float4
  human_sound_landmesh_queries__enemySpeedToQueryInterval : float4
  human_sound_landmesh_queries__heroEnemyInAirInterval : float2
  human_sound_landmesh_queries__lastQueryTime : float
  human_sound_landmesh_queries__biomeQueryId : int
  human_sound_landmesh_queries__puddleQueryId : int
  human_sound_landmesh_queries__biomeId : int
  human_sound_landmesh_queries__puddleQueryToDepth : float4
  human_sound_landmesh_queries__puddleDepth : float
