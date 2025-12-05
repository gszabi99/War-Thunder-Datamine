require ecs
require app
require DaWeaponProps
require %appGame.infantry.es.human_gun_common
require PropsManager

def spawn_shell_impl(eid : EntityId;
                     transform : float3x4;
                     shell_props : PropsId;
                     on_create__setVelocity : float3 const?;
                     on_create__addShellTemplate : das_string const?;
                     on_create__spawnShellTimer : float = -1.0f;
                     ownerEid : EntityId = INVALID_ENTITY_ID)

  var timer = 0.0
  if on_create__spawnShellTimer > 0.0
    timer = on_create__spawnShellTimer
  shell_entity_get_props(shell_props) <| $(shellEntityProp : ShellEntityTypeProps)
    var physTemplName = shellEntityProp |> shell_entity_props_get_physTemplName()

    if on_create__addShellTemplate != null
      let shellTemplateName = *on_create__addShellTemplate |> string()
      physTemplName = add_sub_template_name(physTemplName, shellTemplateName)

    let startVel = (on_create__setVelocity != null
                  ? rotate(transform, *on_create__setVelocity)
                  : float3())
    let createdShell = create_shell_entity(physTemplName, transform, startVel,
                        ownerEid, shell_props, PropsId(),
                         get_sync_time(),
                         get_sync_time() + timer,
                         true,
                         false,
                         INVALID_ENTITY_ID)
    destroyEntity(eid)


[es(tag=server, after=activate_shell_init_shell_prop_es, REQUIRE=on_create__spawnActivatedShellBlk, REQUIRE_NOT=activator__spawnShellAtTime, on_event=EventEntityCreated)]
def spawn_shell_on_create_es(evt : Event;
                             eid : EntityId;
                             transform : float3x4;
                             shell_props : PropsId;
                             on_create__setVelocity : float3 const?;
                             on_create__addShellTemplate : das_string const?;
                             on_create__spawnShellTimer : float = -1.0f;
                             ownerEid : EntityId = INVALID_ENTITY_ID)
  spawn_shell_impl(eid, transform, shell_props, on_create__setVelocity, on_create__addShellTemplate,
                   on_create__spawnShellTimer, ownerEid)

[es(tag=server, REQUIRE=on_create__spawnActivatedShellBlk, no_order)]
def spawn_shell_delayed_spawner_es(info : UpdateStageInfoAct;
                                   eid : EntityId;
                                   transform : float3x4;
                                   activator__spawnShellAtTime : float;
                                   shell_props : PropsId;
                                   on_create__setVelocity : float3 const?;
                                   on_create__addShellTemplate : das_string const?;
                                   on_create__spawnShellTimer : float = -1.0f;
                                   ownerEid : EntityId = INVALID_ENTITY_ID)
  if activator__spawnShellAtTime > 0.f && activator__spawnShellAtTime < info.curTime
    spawn_shell_impl(eid, transform, shell_props, on_create__setVelocity, on_create__addShellTemplate,
                     on_create__spawnShellTimer, ownerEid)

[es(on_appear)]
def delayed_spawn_shell_on_create_init_timer_es(evt : Event;
                                                activator__spawnShellDelay : float;
                                                var activator__spawnShellAtTime : float&)
  activator__spawnShellAtTime = get_sync_time() + activator__spawnShellDelay
