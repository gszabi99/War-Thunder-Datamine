require ecs
require app
require net
require DagorMath
require %game.events
require math.base
require %appGame.wt_events
require %appGame.infantry.es.team_common
require %appGame.infantry.es.fortification_action_common
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_sound_geomtree_nodes_common
require Grid
require AnimV20
require DagorSystem
require GeomNodeTree
require Dacoll
require DagorDataBlock
require hud


[es(tag=gameClient, REQUIRE=(hero, deadEntity), on_appear)]
def reanimation_on_reanimator_death(evt : Event;
                                    eid : EntityId;
                                    var human_reanimator__reanimationAvailable : bool&;
                                    var human_reanimator__reanimatedHumanEid : EntityId&;
                                    var human_reanimator__position : float3&)
  human_reanimator__reanimationAvailable = false
  human_reanimator__reanimatedHumanEid = INVALID_ENTITY_ID
  human_reanimator__position = float3()
  send_net_event(eid, CmdStopReanimation())


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def reanimation_check_availability_on_update(evt : ParallelUpdateFrameDelayed;
                                             eid aka reanimator_eid : EntityId;
                                             team aka reanimator_team : int;
                                             human__aimTm : float3x4;
                                             human_reanimator__reanimationDistance : float;
                                             human_reanimator__reanimationCheckInterval : float;
                                             human_reanimator__reanimationStartTime : float;
                                             var human_reanimator__position : float3&;
                                             var human_reanimator__reanimationNextCheckTime : float&;
                                             var human_reanimator__reanimatedHumanEid : EntityId&;
                                             var human_reanimator__reanimationAvailable : bool&)
  if evt.curTime < human_reanimator__reanimationNextCheckTime
    return
  human_reanimator__reanimationNextCheckTime = evt.curTime + human_reanimator__reanimationCheckInterval

  human_reanimator__reanimationAvailable = false
  human_reanimator__reanimatedHumanEid = INVALID_ENTITY_ID
  human_reanimator__position = float3()
  let TRACE_LEN = 1.0
  var p1 = human__aimTm[3]
  var p2 = p1 + TRACE_LEN * normalize(human__aimTm[0])
  query() <| $ [es] (transform aka camera_transform : float3x4;
                     camera__active : bool)
    if camera__active
      p1 = camera_transform[3]
      p2 = p1 + TRACE_LEN * normalize(camera_transform[2])
  let wasReanimationInProgress = human_reanimator__reanimationStartTime > 0.0
  var resetReanimationProgress = true

  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(p1, human_reanimator__reanimationDistance), GridEntCheck.BOUNDING) <| $(reanimated_eid : EntityId)
    if reanimated_eid == reanimator_eid
      return
    query(reanimated_eid) <| $ [es] (team aka reanimated_team : int;
                                     reanimation__knockedDown : bool;
                                     reanimation__checkNodeId : int;
                                     reanimation__checkNodeRadius : float;
                                     animchar : AnimcharBaseComponent)
      if reanimation__knockedDown && is_teams_friendly(reanimator_team, reanimated_team) && reanimation__checkNodeId >= 0
        let sphereCenter = *animchar.nodeTree |> geomtree_getNodeWpos(reanimation__checkNodeId)
        if test_segment_sphere_intersection_nonblocking(p1, p2, sphereCenter, reanimation__checkNodeRadius)
          var norm : float3
          var dir = sphereCenter - p1
          var t = length(dir)
          dir = dir * safeinv(t)
          if !traceray_normalized(p1, dir, t, norm)
            human_reanimator__reanimationAvailable = true
            human_reanimator__reanimatedHumanEid = reanimated_eid
            human_reanimator__position = sphereCenter
            resetReanimationProgress = false
  if wasReanimationInProgress && resetReanimationProgress
    send_net_event(eid, CmdStopReanimation())


[es(tag=gameClient, on_appear)]
def init_reanimation_check_node_es(evt : Event;
                                   eid : EntityId;
                                   animchar : AnimcharBaseComponent;
                                   reanimation__checkNodeName : string;
                                   var reanimation__checkNodeId : int&)
  reanimation__checkNodeId = *animchar.nodeTree |> geomtree_findNodeIndex(reanimation__checkNodeName)
  if reanimation__checkNodeId < 0
    logerr("eid = {eid}, impossible initialize {reanimation__checkNodeName} node name for reanimation")


[es(tag=gameClient, track=human_reanimator__reanimationStartTime)]
def reanimator_start_animation(evt : Event;
                               eid : EntityId;
                               human_reanimator__reanimationStartTime : float;
                               human_reanimator__reanimationAnimTemplate : string;
                               var human_reanimator__reanimationAnimAffectEid : EntityId&)
  destroyEntity(human_reanimator__reanimationAnimAffectEid)

  if human_reanimator__reanimationStartTime > 0.0
    human_reanimator__reanimationAnimAffectEid = createEntity(human_reanimator__reanimationAnimTemplate) <| $(var init : ComponentsInitializer)
      set(init, "game_effect__attachedTo", eid)


[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=isReplayObserved, track=human_reanimator__reanimationAvailable)]
def human_reanimation_available_tip_show_es(evt : Event;
                                            human_reanimator__reanimationAvailable : bool)
  using() <| $(var eventData : DataBlock)
    hud_notify_script(human_reanimator__reanimationAvailable ? "hint:reanimation_available_show" : "hint:reanimation_available_hide", eventData)


[es(tag=gameClient, on_appear, REQUIRE=(hero, deadEntity), REQUIRE_NOT=isReplayObserved, track=(reanimation__knockedDown, reanimation__askForHelpAvailable))]
def human_decline_reanimation_tip_show_es(evt : Event;
                                          reanimation__knockedDown : bool;
                                          reanimation__askForHelpAvailable : bool)
  using() <| $(var eventData : DataBlock)
    hud_notify_script(reanimation__knockedDown ? "hint:decline_reanimation_tip_show" : "hint:decline_reanimation_tip_hide", eventData)
  let curTime = get_sync_time()
  using() <| $(var eventData : DataBlock)
    hud_notify_script(reanimation__knockedDown && reanimation__askForHelpAvailable ? "hint:ask_for_reanimation_show" : "hint:ask_for_reanimation_hide", eventData)


[es(tag=gameClient, no_order, REQUIRE=(hero, deadEntity))]
def human_ask_for_help_availability_es(evt : ParallelUpdateFrameDelayed;
                                       reanimation__knockedDown : bool;
                                       reanimation__askForHelpAvailableAt : float;
                                       var reanimation__askForHelpAvailable : bool&)
  if reanimation__knockedDown
    reanimation__askForHelpAvailable = evt.curTime > reanimation__askForHelpAvailableAt


[es(tag=sound, REQUIRE=(humanSound, watchedByPlr))]
def human_request_help_sound(evt : CmdRequestHelp;
                             sound_preset__isLoaded : bool;
                             @shared_comp sound_paths : Object;
                             sound_tags : Object;
                             human_hit_sound__prefix : string = "infantry/")
  if sound_preset__isLoaded
    query(evt.requesterEid) <| $ [es] (transform : float3x4;
                                       is_watched_sound : bool;
                                       human_sound_geomtree_nodes__headNodeId = -1;
                                       animchar : AnimcharBaseComponent const?)
      let pos = get_human_voice_3d_pos(is_watched_sound, transform, human_sound_geomtree_nodes__headNodeId, animchar)
      sound_player_common::play_path(evt.soundPath, sound_paths, sound_tags, is_watched_sound, pos, true, human_hit_sound__prefix)
