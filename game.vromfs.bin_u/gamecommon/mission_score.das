require ecs
require MPlayer
require Unit
require HeroManager
require Mission

[es(tag=gameClient, no_order)]
def player_score_update_es(info : UpdateStageInfoAct;
                           m_player : MPlayer;
                           var player__team : int&;
                           var player__score : int&;
                           var player__kills : int&)
  player__team = int(m_player.team)
  player__score = int(m_player.score)
  
  player__kills = m_player.isEmpty ? 0 : int(m_player.kills) + int(m_player.groundKills) + int(m_player.humanKills) + int(m_player.navalKills)

[es(tag=scene, on_event=EventLevelLoaded)]
def mission_score_create_es(evt : Event)
  getOrCreateSingletonEntity("mission_score")

[es(tag=scene, no_order)]
def mission_score_teams_es(info : UpdateStageInfoAct;
                           var mission_score__scoreTeamA : int&;
                           var mission_score__scoreTeamB : int&;
                           var mission_score__ticketsTeamA : int&;
                           var mission_score__ticketsTeamB : int&)
  mission_score__scoreTeamA = get_mp_team_score(int(MultiplayerTeam.MP_TEAM_A))
  mission_score__scoreTeamB = get_mp_team_score(int(MultiplayerTeam.MP_TEAM_B))
  mission_score__ticketsTeamA = get_mp_team_tickets(int(MultiplayerTeam.MP_TEAM_A))
  mission_score__ticketsTeamB = get_mp_team_tickets(int(MultiplayerTeam.MP_TEAM_B))

def set_row(var rows : Array; idx : int; blk : block<(var row : Object) : void>)
  if idx == length(rows)
    using() <| $(var row : Object)
      push(rows, row)
  invoke(blk, *getRW_ecs_object(rows[idx]))

def cut_rows(var rows : Array; count : int)
  while length(rows) > count
    pop(rows)

def to_whole(value : float)
  return int(floor(value + 0.5))

[es(tag=gameClient, no_order)]
def mission_score_update_es(info : UpdateStageInfoAct;
                            var mission_score__bases : Array;
                            var mission_score__captureZones : Array)
  var bases = 0
  for_each_bombing_zone() <| $(zone : BombingZone)
    if zone.isAirfield && zone.army >= int(MultiplayerTeam.MP_TEAM_A) && zone.army <= int(MultiplayerTeam.MP_TEAM_B)
      set_row(mission_score__bases, bases++) <| $(var row)
        set(row, "army", zone.army)
        set(row, "integrity", to_whole(zone.integrity * 100.))
        set(row, "isEnabled", zone.isEnabled)
  cut_rows(mission_score__bases, bases)
  var zones = 0
  if (get_mission_game_type() & uint(MissionGameType.GT_MP_CAPTURE)) != 0x0
    let hero = get_controlled_hero()
    for_each_capture_zone() <| $(zone : CaptureZone)
      if zone.isEnabled
        set_row(mission_score__captureZones, zones++) <| $(var row)
          set(row, "icon", zone.iconIdx)
          set(row, "isBaseMark", zone.canCaptureByGm)
          set(row, "progress", to_whole(zone.captureProgressVal))
          set(row, "isCapturing", abs(zone.captureProgressVal) < abs(float(zone.mpTimeX100)) - 0.1)
          set(row, "canCapture", hero != null && !hero.isDelayed && zone |> canCapture(hero))
  cut_rows(mission_score__captureZones, zones)
