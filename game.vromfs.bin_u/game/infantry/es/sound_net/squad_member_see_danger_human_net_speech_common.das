module squad_member_see_danger_human_net_speech_common shared

require ecs
require ecs.common
require app
require net
require human_net_speech.modules.human_net_speech_request_common
require math
require math.base
require DagorSystem
require %game.utils.net_utils

require %appGame.wt_events


enum SquadMemberSeeDangerSpeechDir : int
  SMSDSD_UNKNOWN = -1
  SMSDSD_AHEAD
  SMSDSD_BEHIND
  SMSDSD_LEFT
  SMSDSD_RIGHT


let IS_ABOVE_DANGER_TRESHOLD = 0.5
let IS_LOOKING_ABOVE_DANGER_TRESHOLD = 0.5
let SPEAKER_TO_LISTENER_MAX_DIST_SQ = square(20.)


def private request_squad_member_see_danger_human_net_speech(speaker_eid, listener_eid : EntityId; dir : SquadMemberSeeDangerSpeechDir)
  let phrase = (dir == (SquadMemberSeeDangerSpeechDir.SMSDSD_LEFT) ? "squadMemberEnemyWarningLeft"
    : dir == (SquadMemberSeeDangerSpeechDir.SMSDSD_RIGHT) ? "squadMemberEnemyWarningRight"
    : dir == (SquadMemberSeeDangerSpeechDir.SMSDSD_BEHIND) ? "squadMemberEnemyWarningBehind"
    : "squadMemberEnemyWarningAhead")
  request_net_speech_for_specific_listener(speaker_eid, phrase, listener_eid)


def private normal_to_speech_direction(norm : float3) : SquadMemberSeeDangerSpeechDir
  let anorm = abs(norm)
  if anorm.y > IS_LOOKING_ABOVE_DANGER_TRESHOLD
    return (SquadMemberSeeDangerSpeechDir.SMSDSD_UNKNOWN)
  if abs(anorm.x) >= abs(anorm.z)
    return norm.x > 0. ? (SquadMemberSeeDangerSpeechDir.SMSDSD_AHEAD) : (SquadMemberSeeDangerSpeechDir.SMSDSD_BEHIND)
  return norm.z > 0. ? (SquadMemberSeeDangerSpeechDir.SMSDSD_LEFT) : (SquadMemberSeeDangerSpeechDir.SMSDSD_RIGHT)


def private find_dir(human__aimTm : float3x4&; danger_pos : float3)
  let worldNorm = normalize(danger_pos - human__aimTm[3])
  if abs(worldNorm.y) > IS_ABOVE_DANGER_TRESHOLD
    return (SquadMemberSeeDangerSpeechDir.SMSDSD_UNKNOWN) 
  let localNorm = normalize(float3(dot(worldNorm, human__aimTm[0]), dot(worldNorm, human__aimTm[1]), dot(worldNorm, human__aimTm[2])))
  return normal_to_speech_direction(localNorm)


def on_squad_member_see_danger_human_net_speech(member_eid aka speaker_eid : EntityId;
                                                danger_eid : EntityId;
                                                danger_pos : float3)

  query(speaker_eid) <| $ [es] (squad_member__squad : EntityId;
                                concussion__isActive : bool;
                                transform aka speaker_transform : float3x4&)
    if concussion__isActive
      return

    let curTime = get_sync_time()
    let speakerSquad = squad_member__squad

    query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid aka listener_eid, squad_member__squad : EntityId;
                                               possessedByPlr : EntityId;
                                               human__aimTm : float3x4;
                                               transform aka listener_transform : float3x4&;

                                               squad_member_see_danger_human_net_speech__updateInterval : float;
                                               var squad_member_see_danger_human_net_speech__nextUpdateAt : float&;

                                               squad_member_see_danger_human_net_speech__ignoreIfNearDangerDistThreshold : float;
                                               squad_member_see_danger_human_net_speech__localDirCooldown : float;
                                               var squad_member_see_danger_human_net_speech__localDirNextTime : float4&;


                                               squad_member_see_danger_human_net_speech__dangersRememberTime : float;
                                               squad_member_see_danger_human_net_speech__similarDangersDotThreshold : float;
                                               var squad_member_see_danger_human_net_speech__dangers : EidList&;
                                               var squad_member_see_danger_human_net_speech__forgetAfter : FloatList&)
      if curTime < squad_member_see_danger_human_net_speech__nextUpdateAt
        return

      if squad_member__squad == speakerSquad && listener_eid != speaker_eid && !!possessedByPlr && !has(possessedByPlr, "playerIsBot")
        if distance_sq(speaker_transform[3], listener_transform[3]) > SPEAKER_TO_LISTENER_MAX_DIST_SQ
          return 

        if distance_sq(danger_pos, listener_transform[3]) < square(squad_member_see_danger_human_net_speech__ignoreIfNearDangerDistThreshold)
          return 

        let localDir = find_dir(human__aimTm, danger_pos)
        if localDir == (SquadMemberSeeDangerSpeechDir.SMSDSD_UNKNOWN)
          return

        assert(length(squad_member_see_danger_human_net_speech__dangers) == length(squad_member_see_danger_human_net_speech__forgetAfter))

        

        var idx = length(squad_member_see_danger_human_net_speech__dangers)
        while --idx >= 0
          if curTime > squad_member_see_danger_human_net_speech__forgetAfter[idx]
            squad_member_see_danger_human_net_speech__dangers |> erase(idx)
            squad_member_see_danger_human_net_speech__forgetAfter |> erase(idx)

        

        let forgetAfter = curTime + squad_member_see_danger_human_net_speech__dangersRememberTime
        idx = squad_member_see_danger_human_net_speech__dangers |> find_index(danger_eid)
        if idx >= 0
          squad_member_see_danger_human_net_speech__forgetAfter[idx] = forgetAfter
          return

        squad_member_see_danger_human_net_speech__dangers |> push(danger_eid)
        squad_member_see_danger_human_net_speech__forgetAfter |> push(forgetAfter)

        

        let worldNorm = normalize((danger_pos - listener_transform[3]).xz)
        for dangerEid in squad_member_see_danger_human_net_speech__dangers
          if dangerEid != danger_eid
            var d = 0.
            query(dangerEid) <| $ [es] (transform : float3x4&)
              d = dot(normalize((transform[3] - listener_transform[3]).xz), worldNorm)
            if d >= squad_member_see_danger_human_net_speech__similarDangersDotThreshold
              return

        

        assert(uint(localDir) <= 4u)
        assume localDirNextTime = squad_member_see_danger_human_net_speech__localDirNextTime[int(localDir)]
        if localDirNextTime >= 0. && curTime < localDirNextTime
          return
        squad_member_see_danger_human_net_speech__localDirNextTime[int(localDir)] = curTime + squad_member_see_danger_human_net_speech__localDirCooldown

        

        request_squad_member_see_danger_human_net_speech(speaker_eid, listener_eid, localDir)
        squad_member_see_danger_human_net_speech__nextUpdateAt = curTime + squad_member_see_danger_human_net_speech__updateInterval
        sendEvent(listener_eid, CmdCreateHudTacticalMapDangerIcon(worldPos = danger_pos, blinkTime = 10.f))
