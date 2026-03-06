require ecs
require app
require walkerai
require math.base
require math.random
require DagorMath
require %appGame.infantry.ai.ai_squad_tactical_common
require %appGame.infantry.es.team_common
require %appGame.wt_events
require %game.events
require DaWeaponProps
require PropsManager
require Weapon
require Grid

require DagorDebug3D


[es(tag=server, no_order)]
def ai_listening_es(act : UpdateStageInfoAct;
                    squad_member__squad : EntityId;
                    transform aka agent_transform : float3x4;
                    isAlive aka agent_isAlive : bool = true;
                    agent__listening : bool;
                    var agent__listeningNextTime : float&;
                    var agent__listeningTimeDelta : float&;
                    agent__listeningDelay : float2;
                    var agent__listeningKind1 : int&;
                    var agent__listeningKind2 : int&;
                    var agent__listeningEid1 : EntityId&;
                    var agent__listeningEid2 : EntityId&;
                    var agent__listeningNoise1 : float&;
                    var agent__listeningNoise2 : float&;
                    agent__listeningNoiseFadeTau : float;
                    agent__listeningNoiseGrowInvTimeCoef : float;
                    agent__listeningNoiseDistCoefs : float2;
                    var agent__listeningWhat : int3&;
                    var agent__listeningEid : EntityId&;
                    var agent__listeningPos : float3&;
                    agent__listeningMinDistToCount : float;
                    agent__listeningMinNoiseValue : float;
                    agent__listeningNoiseExact : float;
                    agent_dangers : AgentDangers)
  if !agent__listening || !agent_isAlive
    return
  let curTime = get_sync_time()
  if curTime < agent__listeningNextTime
    return
  agent__listeningTimeDelta = rnd_float(agent__listeningDelay.x, agent__listeningDelay.y)
  agent__listeningNextTime = curTime + agent__listeningTimeDelta

  let applyDeltaTime = agent__listeningTimeDelta

  agent__listeningNoise1 = approach(agent__listeningNoise1, 0.0, applyDeltaTime, agent__listeningNoiseFadeTau)
  agent__listeningNoise2 = approach(agent__listeningNoise1, 0.0, applyDeltaTime, agent__listeningNoiseFadeTau)

  let minDistSq = square(agent__listeningNoiseDistCoefs.x)
  let maxDistSq = square(agent__listeningNoiseDistCoefs.y)

  for danger in agent_dangers.dangers
    if danger.traceable
      if danger.eid == agent__listeningEid1
        agent__listeningEid1 = INVALID_ENTITY_ID
      elif danger.eid == agent__listeningEid2
        agent__listeningEid2 = INVALID_ENTITY_ID

  for danger in agent_dangers.dangers
    if danger.traceable
      continue
    query(danger.eid) <| $ [es] (unit_tag__human : Tag const?;
                                 ai_target__noiseLevel : float;
                                 transform aka danger_transform : float3x4;
                                 isAlive aka danger_isAlive : bool = true)
      let distSq = distance_sq(agent_transform[3], danger_transform[3])
      if distSq > maxDistSq || !danger_isAlive
        return

      let kind = unit_tag__human != null ? 1 : 2
      let noiseCoef = cvt(distSq, minDistSq, maxDistSq, 1.0, 0.0)
      let noiseInDistLevel = ai_target__noiseLevel * noiseCoef
      if noiseInDistLevel < agent__listeningMinNoiseValue
        return

      let ratio = applyDeltaTime * agent__listeningNoiseGrowInvTimeCoef
      let noiseAdd = lerp(0.0, noiseInDistLevel, ratio)

      

      if danger.eid == agent__listeningEid1
        agent__listeningNoise1 = agent__listeningNoise1 + noiseAdd
      elif danger.eid == agent__listeningEid2
        agent__listeningNoise2 = agent__listeningNoise2 + noiseAdd
      elif agent__listeningNoise1 < agent__listeningNoise2 && noiseInDistLevel > agent__listeningNoise1
        agent__listeningKind1 = kind
        agent__listeningEid1 = danger.eid
        agent__listeningNoise1 = noiseAdd
      elif noiseInDistLevel > agent__listeningNoise2
        agent__listeningKind2 = kind
        agent__listeningEid2 = danger.eid
        agent__listeningNoise2 = noiseAdd

  
  
  
  
  
  
  
  
  
  

  var tryKind = 0
  var tryEid = INVALID_ENTITY_ID
  var tryNoise = agent__listeningMinNoiseValue
  if agent__listeningEid1 != INVALID_ENTITY_ID && agent__listeningNoise1 > tryNoise
    tryKind = agent__listeningKind1
    tryEid = agent__listeningEid1
    tryNoise = agent__listeningNoise1
  if agent__listeningEid2 != INVALID_ENTITY_ID && agent__listeningNoise2 > tryNoise
    if !(tryKind == 1 && agent__listeningKind1 == 2) 
      tryKind = agent__listeningKind2
      tryEid = agent__listeningEid2
      tryNoise = agent__listeningNoise2
  if tryEid == INVALID_ENTITY_ID
    return

  if tryEid != agent__listeningEid
    agent__listeningWhat.x = tryKind
    agent__listeningWhat.y = 0
    agent__listeningEid = tryEid

  query(agent__listeningEid) <| $ [es] (transform aka danger_transform : float3x4;
                                        isAlive aka danger_isAlive : bool = true)
    if !danger_isAlive
      return

    
    
    

    let approachTau = cvt(tryNoise, 0.0, agent__listeningNoiseExact, 1.0, 0.0)
    agent__listeningPos = approach(agent__listeningPos, danger_transform[3], applyDeltaTime, approachTau)

    
    

    let distSq = distance_sq(agent__listeningPos, danger_transform[3])
    if distSq < square(agent__listeningMinDistToCount)
      agent__listeningWhat.y += 1
      if agent__listeningWhat.y >= agent__listeningWhat.z
        
        
        ai_squad_tactical_add_update_target(squad_member__squad, agent__listeningEid, agent__listeningPos, false)


[es(tag=server)]
def ai_listening_on_plant_wall_mine_es(evt : CmdStartPlantingMineOnWall; eid aka offender_eid : EntityId; isDowned : bool)
  if isDowned
    return

  var offenderTeam = -1
  query(offender_eid) <| $ [es] (team : int)
    offenderTeam = team

  var squads : array<EntityId>
  squads |> reserve(16)

  let RECENT_TARGET_TIME = 5.0
  let DETECT_PLANT_MINE_DISTANCE = 15.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(evt.pos, DETECT_PLANT_MINE_DISTANCE), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
    query(that_eid) <| $ [es] (team : int; transform : float3x4; squad_member__squad : EntityId)
      if is_teams_friendly(team, offenderTeam)
        return
      if distance_sq(transform[3], evt.pos) > square(DETECT_PLANT_MINE_DISTANCE)
        return
      if find_index(squads, squad_member__squad) != -1
        return
      squads |> push(squad_member__squad)
      if ai_squad_tactical_has_recent_target(squad_member__squad, offender_eid, RECENT_TARGET_TIME)
        return

      
      
      ai_squad_tactical_add_update_target(squad_member__squad, offender_eid, false)

[es(tag=server)]
def ai_listening_on_visual_explosion_es(evt : EventOnVisualExplosion)
  var offenderTeam = -1
  query(evt.offender_eid) <| $ [es] (team : int)
    offenderTeam = team

  var squads : array<EntityId>
  squads |> reserve(16)

  let RECENT_TARGET_TIME = 5.0
  let DETECT_EXPLOSION_DISTANCE = 42.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(evt.pos, DETECT_EXPLOSION_DISTANCE), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
    query(that_eid) <| $ [es] (team : int; transform : float3x4; squad_member__squad : EntityId)
      if is_teams_friendly(team, offenderTeam)
        return
      if distance_sq(transform[3], evt.pos) > square(DETECT_EXPLOSION_DISTANCE)
        return
      if find_index(squads, squad_member__squad) != -1
        return
      squads |> push(squad_member__squad)
      if ai_squad_tactical_has_recent_target(squad_member__squad, evt.offender_eid, RECENT_TARGET_TIME)
        return

      
      
      ai_squad_tactical_add_update_target(squad_member__squad, evt.offender_eid, false)

[es(tag=server, on_appear, REQUIRE=shell__explTime)]
def ai_listening_on_grenade_es(evt : Event;
                               transform aka shell_transform : float3x4;
                               shell__owner : EntityId;
                               shell__shell_id__shell_id : PropsId)
  let damageRadius = get_shell_max_radius(shell__shell_id__shell_id)
  if damageRadius < 0.1
    return

  var offenderTeam = -1
  let offenderEid = shell__owner
  query(offenderEid) <| $ [es] (squad_member__playerEid : EntityId)
    query(squad_member__playerEid) <| $ [es] (team : int)
      offenderTeam = team
  if offenderTeam < 0
    return

  var squads : array<EntityId>
  squads |> reserve(16)

  let grenadePos = shell_transform[3]
  

  let RECENT_TARGET_TIME = 5.0
  let DETECT_THROWER_DISTANCE = 25.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(grenadePos, DETECT_THROWER_DISTANCE), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
    query(that_eid) <| $ [es] (team : int; transform : float3x4; squad_member__squad : EntityId)
      if is_teams_friendly(team, offenderTeam)
        return
      if distance_sq(transform[3], grenadePos) > square(DETECT_THROWER_DISTANCE)
        return
      if find_index(squads, squad_member__squad) != -1
        return
      squads |> push(squad_member__squad)
      if ai_squad_tactical_has_recent_target(squad_member__squad, offenderEid, RECENT_TARGET_TIME)
        return

      
        
        
        
      ai_squad_tactical_add_update_target(squad_member__squad, offenderEid, false)

[es(tag=server)]
def ai_listening_on_shot_es(evt : EventShot; gun__owner : EntityId; gun__curShellId : PropsId)
  var ignoreShot = false
  shell_entity_get_props(gun__curShellId) <| $(entProps : ShellEntityTypeProps)
    let templName = entProps.templName
    if !(templName == "")
      ignoreShot = true
  if ignoreShot
    return

  let offenderEid = gun__owner
  var offenderTeam = -1
  query(offenderEid) <| $ [es(REQUIRE=unit_tag__human)] (team : int)
    offenderTeam = team
  if offenderTeam < 0
    return

  var squads : array<EntityId>
  squads |> reserve(16)

  let shotPos = evt.launchDesc.tm[3]
  

  let RECENT_TARGET_TIME = 5.0
  let DETECT_SHOOTER_DISTANCE = 35.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(shotPos, DETECT_SHOOTER_DISTANCE), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
    query(that_eid) <| $ [es] (team : int; transform : float3x4; squad_member__squad : EntityId)
      if is_teams_friendly(team, offenderTeam)
        return
      if distance_sq(transform[3], shotPos) > square(DETECT_SHOOTER_DISTANCE)
        return
      if find_index(squads, squad_member__squad) != -1
        return
      squads |> push(squad_member__squad)
      if ai_squad_tactical_has_recent_target(squad_member__squad, offenderEid, RECENT_TARGET_TIME)
        return

      
      
      
      ai_squad_tactical_add_update_target(squad_member__squad, offenderEid, false)

[es(tag=server)]
def ai_listening_on_door_state_changed_es(evt : EventDoorChangeStateRequest; eid aka door_eid : EntityId)
  
  var doorPos = float3()
  var doorDirOff = float3()
  var hasDoor = false
  query(door_eid) <| $ [es] (initialTransform : float3x4)
    doorPos = initialTransform[3]
    let ALONG_DOOR_DIST = 0.7
    doorPos += initialTransform[0] * ALONG_DOOR_DIST
    doorDirOff = initialTransform[2]
    hasDoor = true
  if !hasDoor
    return

  var offenderEid1 = INVALID_ENTITY_ID
  var offenderEid2 = INVALID_ENTITY_ID
  var offenderDistSq1 = 0.0
  var offenderDistSq2 = 0.0
  var offenderPos1 = float3()
  var offenderPos2 = float3()

  let OPENER_DETECT_DISTANCE = 5.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(doorPos, OPENER_DETECT_DISTANCE), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
    query(that_eid) <| $ [es] (team : int; transform : float3x4)
      let offenderPos = transform[3]
      let distSq = distance_sq(offenderPos, doorPos)
      if distSq > square(OPENER_DETECT_DISTANCE)
        return
      if team == 1
        if offenderEid1 == INVALID_ENTITY_ID || distSq < offenderDistSq1
          offenderEid1 = that_eid
          offenderDistSq1 = distSq
          offenderPos1 = offenderPos
      elif team == 2
        if offenderEid2 == INVALID_ENTITY_ID || distSq < offenderDistSq2
          offenderEid2 = that_eid
          offenderDistSq2 = distSq
          offenderPos2 = offenderPos

  
  
  
  

  var squads : array<EntityId>
  squads |> reserve(16)

  let RECENT_TARGET_TIME = 5.0
  let DETECT_DOOR_DISTANCE = 25.0
  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(doorPos, DETECT_DOOR_DISTANCE), GridEntCheck.BOUNDING) <| $(that_eid : EntityId)
    query(that_eid) <| $ [es] (team : int; transform : float3x4; squad_member__squad : EntityId)
      let distSq = distance_sq(doorPos, transform[3])
      if distSq > square(DETECT_DOOR_DISTANCE)
        return
      let offenderEid = team == 1 ? offenderEid2 : team == 2 ? offenderEid1 : INVALID_ENTITY_ID
      if offenderEid == INVALID_ENTITY_ID
        return
      let offenderPos = team == 1 ? offenderPos2 : offenderPos1

      let OFF_DOOR_DIST = 0.7
      let offDirCoef = dot(offenderPos - doorPos, doorDirOff) > 0.0 ? -1.0 : 1.0
      let awarePos = doorPos + doorDirOff * OFF_DOOR_DIST * offDirCoef

      
      
      if ai_squad_tactical_has_recent_target(squad_member__squad, offenderEid, RECENT_TARGET_TIME)
        return
      ai_squad_tactical_add_update_target(squad_member__squad, offenderEid, awarePos, false)
