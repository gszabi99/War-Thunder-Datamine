require ecs
require DagorMath
require DagorRandom
require %appGame.infantry.es.team_common
require math
require math.base

struct MeanPos
  eid : EntityId
  team : int
  pos : float3
  accumPos : float3
  amountOfPoints : int

def random_circle_offset(min_max_radius : float2)
  let rndAngle  = rnd_float(0.0, TWOPI)
  let rndRadius = rnd_float(min_max_radius.x, min_max_radius.y)
  var cosAngle = 0.
  var sinAngle = 0.
  sincos(rndAngle, sinAngle, cosAngle)
  return float3(cosAngle * rndRadius, 0., sinAngle * rndRadius)

[es(tag=server, no_order)]
def kmeans_enemy_pos(act : UpdateStageInfoAct)
  var posCache : array<MeanPos>
  var noiseRadius = float2()
  var noiseAmount = float3(0.0, 1.0, 1.0)
  query <| $ [es] (eid : EntityId;
                   mean_pos__pos : float3&;
                   mean_pos__team : int;
                   mean_pos__noiseRadius : float2 = float2();
                   mean_pos__noiseAmount : float3 = float3(0.0, 1.0, 1.0))
    noiseRadius = mean_pos__noiseRadius
    noiseAmount = mean_pos__noiseAmount
    posCache |> emplace(MeanPos(eid = eid, team = mean_pos__team, pos = mean_pos__pos))
  if posCache |> empty()
    return
  var enemyPoints : array<tuple<team : int; offset : float3> >
  query <| $ [es] (isAlive : bool; transform : float3x4; team : int)
    if !isAlive
      return
    var closest = -1
    var bestDist = FLT_MAX
    enemyPoints |> emplace((team, transform[3]))
    for pos, i in posCache, iter_range(posCache)
      if pos.team != TEAM_UNASSIGNED && team != pos.team
        continue
      let dist = length_sq(pos.pos - transform[3])
      if dist < bestDist
        closest = i
        bestDist = dist
    if closest > -1
      posCache[closest].accumPos += transform[3]
      posCache[closest].amountOfPoints++
  for pos in posCache
    if pos.amountOfPoints > 0
      let amount = float(pos.amountOfPoints)
      var meanPos = pos.accumPos * safeinv(amount)
      if noiseRadius.y > 0.0
        let noiseCoef = cvt(amount, noiseAmount.x, noiseAmount.y, 1.0, noiseAmount.z)
        meanPos += random_circle_offset(noiseRadius * noiseCoef)
      query(pos.eid) <| $ [es] (var mean_pos__pos : float3&)
        mean_pos__pos = meanPos
    elif !(enemyPoints |> empty()) 
      var countPoints = enemyPoints |> length()
      if pos.team != TEAM_UNASSIGNED
        for pt in enemyPoints
          if pt.team == pos.team
            countPoints += 1
      if countPoints > 0
        var rndIdx = grnd() % countPoints
        for pt in enemyPoints
          if pt.team != pos.team
            continue
          if rndIdx == 0
            query(pos.eid) <| $ [es] (var mean_pos__pos : float3&)
              mean_pos__pos = pt.offset
            break
          rndIdx--