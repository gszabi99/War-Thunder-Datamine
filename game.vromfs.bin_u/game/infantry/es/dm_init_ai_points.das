require ecs
require DagorMath
require strings
require dm
require WTDamageModel
require CollRes
require Unit

require %appGame.infantry.es.dm_ai_common


def private get_dm_ai_point_type_from_string(str : string)
  if str == "TURRET"
    return DMAIPoint.TURRET
  if str == "BARREL"
    return DMAIPoint.BARREL
  if str == "TRACK"
    return DMAIPoint.TRACK
  if str == "WHEEL"
    return DMAIPoint.WHEEL
  if str == "ENGINE"
    return DMAIPoint.ENGINE
  if str == "CREW"
    return DMAIPoint.CREW
  return DMAIPoint.BODY
























[es(tag=server, on_appear)]
def dm_init_ai_points(evt : Event;
                      transform : float3x4;
                      unit__ref : UnitRef;
                      var dm_ai__points : Point3List&;
                      var dm_ai__pointsInfo : IPoint2List&;
                      var dm_ai__pointsYRange : float2&;
                      @shared_comp dm_ai__filters : Array)
  dm_ai__points |> clear()
  dm_ai__pointsInfo |> clear()
  dm_ai__pointsYRange = float2()

  let unit = unit__ref.unit
  if unit == null || unit.visual == null
    return
  let collres = unit.visual.collisionResource
  if collres == null
    return

  let numFilters = length(dm_ai__filters)
  var numSlots = 0

  var filters : array<int>
  var ftypes : array<int>
  var fmaxes : array<int>
  var fmergs : array<bool>
  var fcount : array<int>
  resize(filters, numFilters)
  resize(ftypes, numFilters)
  resize(fmaxes, numFilters)
  resize(fmergs, numFilters)
  resize(fcount, numFilters)

  for i in iter_range(dm_ai__filters)
    filters[i] = numSlots
    let filter = get_ecs_object(dm_ai__filters[i])
    let ftype = get_ecs_string(filter, "type")
    let fmax = max(1, get_int(filter, "max") ?? 1)
    let fmerge = get_bool(filter, "merge") ?? false
    ftypes[i] = int(ftype != null ? get_dm_ai_point_type_from_string(string(*ftype)) : DMAIPoint.BODY)
    fmaxes[i] = fmax
    fmergs[i] = fmerge
    numSlots += fmax

  var slotCnt : array<int>
  var slotPos : array<float3>
  var slotPart : array<int>
  resize(slotCnt, numSlots)
  resize(slotPos, numSlots)
  resize(slotPart, numSlots)
  for i in range(numSlots)
    slotPart[i] = -1

  var bodyPos = float3()
  var bodyCnt = 0

  let inverseTm = inverse(transform)

  assume dmData = unit.dmData
  let numParts = get_damage_part_props_count(dmData)

  for partId in range(numParts)
    if !get_damage_part_props(dmData, partId).enabled
      continue

    let partName = get_part_name(dmData, partId)

    var fidx = -1
    var pidx = 0
    for i in range(numFilters)
      let filter = get_ecs_object(dm_ai__filters[i])
      let fmaskRef = get_ecs_string(filter, "mask")
      if fmaskRef == null
        continue
      let fmask = string(*fmaskRef)
      let maskLen = length(fmask)
      if maskLen <= 0
        continue
      if maskLen > 1
        let lastChar = character_at(fmask, maskLen - 1)
        if !is_alnum(lastChar) && lastChar != '_'
          if starts_with(partName, fmask, uint(maskLen - 1))
            if lastChar == '*'
              if fmergs[i]
                fidx = i
                pidx = 0
              elif fcount[i] < fmaxes[i]
                fidx = i
                pidx = fcount[i]
              break
            elif lastChar == '#'
              var npos = maskLen - 1
              var nval = 0
              var gotn = false
              while is_number(character_at(partName, npos))
                gotn = true
                nval = nval * 10 + (character_at(partName, npos) - '0')
                ++npos
              if !gotn
                continue
              if nval > 0 && nval - 1 < fmaxes[i]
                fidx = i
                pidx = nval - 1
              break
            elif lastChar == '$'
              var npos = maskLen - 1
              var nval = 0
              var gotn = false
              while is_number(character_at(partName, npos))
                gotn = true
                nval = nval * 10 + (character_at(partName, npos) - '0')
                ++npos
              if !gotn
                fidx = i
                pidx = 0
              elif nval > 0 && nval < fmaxes[i]
                fidx = i
                pidx = nval
              break
      if partName == fmask
        fidx = i
        pidx = 0
        break

    let collNodeId = get_collision_node_id(dmData, partId)
    if collNodeId < 0
      continue
    let collNode = *collres |> collres_get_node(collNodeId)
    if collNode == null
      continue

    let bbox = collNode.modelBBox
    let localPos = bbox.center

    var nodeTm : float3x4
    *collres |> collres_get_collision_node_tm(collNodeId, transform, unit.collNodeTree, nodeTm)
    let localTmPos = inverseTm * nodeTm * localPos

    if fidx < 0
      bodyCnt += 1
      bodyPos += localTmPos
      continue

    fcount[fidx] = max(fcount[fidx], pidx + 1)

    if pidx < 0 || pidx >= fmaxes[fidx]
      continue

    let sidx = filters[fidx] + pidx
    if ftypes[fidx] == int(DMAIPoint.BARREL)
      slotPart[sidx] = partId
      slotPos[sidx] = localPos
      slotCnt[sidx] = 1
    else
      slotPart[sidx] = slotPart[sidx] == -1 ? partId : -2
      slotCnt[sidx] += 1
      slotPos[sidx] += localTmPos

  for i in range(numFilters)
    let ftype = ftypes[i]
    let fslots = fcount[i]
    for j in range(fslots)
      let sidx = filters[i] + j
      if slotCnt[sidx] > 0
        let avgPos = slotPos[sidx] / float(slotCnt[sidx])
        let partId = slotPart[sidx]
        let localPartId = ftype == int(DMAIPoint.BARREL) ? partId : -1
        dm_ai__points |> push(avgPos)
        dm_ai__pointsInfo |> push(int2(localPartId, ftype))
        if ftype == int(DMAIPoint.TRACK) && partId >= 0 && slotCnt[sidx] == 1
          let collNodeId = get_collision_node_id(dmData, partId)
          if collNodeId >= 0
            let collNode = *collres |> collres_get_node(collNodeId)
            if collNode != null
              let bbox = collNode.modelBBox
              let offs = float3(bbox.width.x * 0.3, 0.0, 0.0)
              dm_ai__points |> push(avgPos + offs)
              dm_ai__pointsInfo |> push(int2(localPartId, ftype))
              dm_ai__points |> push(avgPos - offs)
              dm_ai__pointsInfo |> push(int2(localPartId, ftype))

  if bodyCnt > 0
    let bodyAvgPos = bodyPos / float(bodyCnt)
    dm_ai__points |> push(bodyAvgPos)
    dm_ai__pointsInfo |> push(int2(-1, int(DMAIPoint.BODY)))

  if empty(dm_ai__points)
    let DEFAULT_CENTER_POS = float3(0.0, 1.5, 0.0)
    dm_ai__points |> push(DEFAULT_CENTER_POS)
    dm_ai__pointsInfo |> push(int2(-1, int(DMAIPoint.BODY)))

  if !empty(dm_ai__points)
    for pt in dm_ai__points
      dm_ai__pointsYRange.x = min(dm_ai__pointsYRange.x, pt.y)
      dm_ai__pointsYRange.y = max(dm_ai__pointsYRange.y, pt.y)
