module aim_assist_common shared
require ecs
require math
require math.ang
require math.base
require DagorMath
require Grid
require AnimV20
require GeomNodeTree
require %appGame.infantry.es.team_common


struct AssistTarget
  score : float
  eid : EntityId
  dp : float
  dist : float
  dir : float3
  pos : float3


def get_assist_targets(shoot_pos, shoot_dir : float3; max_dist, max_width, min_angle_cos : float; my_team : int) : array<AssistTarget>
  let wishTag = "human"
  var targets : array<AssistTarget>
  for_each_entity_in_grid(ecs_hash("humans"), shoot_pos, shoot_dir, max_dist, max_width, GridEntCheck.POS) <| $ [unused_argument(pos)] (eid : EntityId; pos : float3)
    ecs::query(eid) <| $ [es] (animchar : AnimcharBaseComponent;
                               agent_dangers__tag : string;
                               aim_assist_target__nodeIdx : int;
                               team : int;
                               isAlive : bool)
      if !isAlive || agent_dangers__tag != wishTag || is_teams_friendly(my_team, team) || aim_assist_target__nodeIdx < 0
        return
      let aimPos = geomtree_getNodeWpos(*animchar.nodeTree, aim_assist_target__nodeIdx)
      var dir = aimPos - shoot_pos
      let dist = length(dir)
      if dist > max_dist
        return
      dir *= rcp(dist)
      let targetAngleCos = dot(dir, shoot_dir)
      if targetAngleCos < min_angle_cos
        return
      let score = cvt(targetAngleCos, min_angle_cos, 1.0, 0.0, 1.0) * (max_dist - dist) / max_dist
      targets |> emplace(AssistTarget(score = score, eid = eid, dp = targetAngleCos, dist = dist, dir = dir, pos = aimPos))
  sort(targets) <| $(lhs, rhs : AssistTarget)
    return lhs.score > rhs.score
  return <- targets


def get_assist_angle_progress(dist_to_target, angle_to_target_cos, max_assist_angle, assist_cone_max_width : float) : float
  let maxCos = sqrt(1.0 - square(assist_cone_max_width / dist_to_target))
  return cvt(angle_to_target_cos, max(cos(deg_to_rad(max_assist_angle)), maxCos), 1.0, 0.0, 1.0)


def get_assist_radius(dist_to_target, max_assist_angle, assist_cone_max_width : float) : float
  return min(dist_to_target * sin(deg_to_rad(max_assist_angle)), assist_cone_max_width)
