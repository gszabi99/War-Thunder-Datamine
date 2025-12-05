module human_context_command_point_common shared

require ecs
require math
require math.base
require app
require DagorDebug3D
require DagorMath
require AnimV20
require Dacoll
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require %appGame.infantry.input.human_context_command_camera_common
require %appGame.infantry.es.walker_common
require %appGame.infantry.es.team_common
require Mission


enum HumanPointOrderPose
  STANDING
  CROUCHED
  PRONE

enum HumanPointOrderType
  NOT_POINT_ORDER = 0
  POINT_TAKE_POSITION = 1
  POINT_DETECT_CONTEXT = 2
  POINT_THROW_FRAG_GRENADE = 3
  POINT_THROW_SMOKE_GRENADE = 4
  POINT_THROW_FLASH_GRENADE = 5

enum HumanPointOrderSubtype
  POINT_TAKE_POSITION_OVERWATCH = 0
  POINT_TAKE_POSITION_PEEKOUT_LEFT = 1
  POINT_TAKE_POSITION_PEEKOUT_RIGHT = 2
  POINT_TAKE_POSITION_PEEKOUT_UP = 3

enum HumanPointTargetKind
  NONOBJ = 0
  DOOR = 1
  HUMAN = 2
  VEHICLE = 3
  DESTROYABLE_WALL = 4

struct PositionalOrderInfo
  subtype : HumanPointOrderSubtype
  pos : float3
  dir : float3
  toPos : float3
  toDir : float3

def is_human_point_order_cancellable(order_type : int)
  return order_type == int(HumanPointOrderType.POINT_TAKE_POSITION)

def is_human_point_order_await_shoot_accept(order_type : int)
  if order_type == int(HumanPointOrderType.POINT_THROW_FRAG_GRENADE)
    return true
  if order_type == int(HumanPointOrderType.POINT_THROW_SMOKE_GRENADE)
    return true
  if order_type == int(HumanPointOrderType.POINT_THROW_FLASH_GRENADE)
    return true
  return false


def human_point_obj_make_tm(var tm : float3x4&; pos : float3; dir : float3; norm : float3)
  let normDir = dir - dot(dir, norm) * norm
  tm[0] = normDir
  tm[1] = norm
  tm[2] = normalize(cross(dir, norm))
  tm[3] = pos

enum private HumanPointOrderPeekoutModel
  PEEKOUT_STANDING_LEFT = 0
  PEEKOUT_STANDING_RIGHT = 1
  PEEKOUT_CROUCHED_LEFT = 2
  PEEKOUT_CROUCHED_RIGHT = 3
  PEEKOUT_CROUCHED_UP = 4

def private human_point_order_is_peekout_subtype(subtype : int) : bool
  return (subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_LEFT) ||
         subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_RIGHT) ||
         subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_UP))

def private human_point_order_get_peekout_model_index(order_subtype : int; pose : int) : int
  let isLeanLeft = order_subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_LEFT)
  if pose == int(HumanPointOrderPose.STANDING)
    return isLeanLeft ? int(HumanPointOrderPeekoutModel.PEEKOUT_STANDING_LEFT) : int(HumanPointOrderPeekoutModel.PEEKOUT_STANDING_RIGHT)
  elif pose == int(HumanPointOrderPose.CROUCHED)
    if order_subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_UP)
      return int(HumanPointOrderPeekoutModel.PEEKOUT_CROUCHED_UP)
    return isLeanLeft ? int(HumanPointOrderPeekoutModel.PEEKOUT_CROUCHED_LEFT) : int(HumanPointOrderPeekoutModel.PEEKOUT_CROUCHED_RIGHT)
  else
    return -1

def human_point_order_obj_recreate(human_eid : EntityId)
  query(human_eid) <| $ [es] (human_context_command__pointOrder : int;
                              human_context_command__pointOrderSubtype : int;
                              human_context_command__pointOrderPos : float3;
                              human_context_command__pointOrderDir : float3;
                              human_context_command__pointOrderNorm : float3;
                              human_context_command__pointOrderPose : int;
                              var human_context_command__pointObjEid : EntityId&;
                              var human_context_command__pointObjTransform : float3x4&;
                              human_context_command__pointObjTemplate : string;
                              human_context_command__pointObjResCompName : string;
                              human_context_command__pointObjObject_Overwatch : StringList;
                              human_context_command__pointObjTransform_Overwatch : TMatrixList;
                              human_context_command__pointObjIconOffsetY_Overwatch : FloatList;
                              human_context_command__pointObjObject_Peekout : StringList;
                              human_context_command__pointObjTransform_Peekout : TMatrixList;
                              human_context_command__pointObjObject_ThrowGrenade : string;
                              human_context_command__pointObjTransform_ThrowGrenade : float3x4)
    if human_context_command__pointObjEid != INVALID_ENTITY_ID
      destroyEntity(human_context_command__pointObjEid)
      human_context_command__pointObjEid = INVALID_ENTITY_ID

    var orderObjName = "" 
    var orderIconOffsetY = 0.0
    var orderObjTransform = IDENT_TM

    if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
      let byPose = human_context_command__pointOrderPose
      let subtype = human_context_command__pointOrderSubtype
      if subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH)
        if byPose >= 0 && byPose < length(human_context_command__pointObjObject_Overwatch)
          orderObjName = string(human_context_command__pointObjObject_Overwatch[byPose])
        if byPose >= 0 && byPose < length(human_context_command__pointObjTransform_Overwatch)
          orderObjTransform = human_context_command__pointObjTransform_Overwatch[byPose]
        if byPose >= 0 && byPose < length(human_context_command__pointObjIconOffsetY_Overwatch)
          orderIconOffsetY = human_context_command__pointObjIconOffsetY_Overwatch[byPose]
      elif human_point_order_is_peekout_subtype(subtype)
        let modelIndex = human_point_order_get_peekout_model_index(subtype, byPose)
        if modelIndex >= 0 && modelIndex < length(human_context_command__pointObjObject_Peekout)
          orderObjName = string(human_context_command__pointObjObject_Peekout[modelIndex])
        if modelIndex >= 0 && modelIndex < length(human_context_command__pointObjTransform_Peekout)
          orderObjTransform = human_context_command__pointObjTransform_Peekout[modelIndex]
    elif human_context_command__pointOrder == int(HumanPointOrderType.POINT_THROW_FRAG_GRENADE)
      orderObjName = human_context_command__pointObjObject_ThrowGrenade
      orderObjTransform = human_context_command__pointObjTransform_ThrowGrenade
    elif human_context_command__pointOrder == int(HumanPointOrderType.POINT_THROW_SMOKE_GRENADE)
      orderObjName = human_context_command__pointObjObject_ThrowGrenade
      orderObjTransform = human_context_command__pointObjTransform_ThrowGrenade
    elif human_context_command__pointOrder == int(HumanPointOrderType.POINT_THROW_FLASH_GRENADE)
      orderObjName = human_context_command__pointObjObject_ThrowGrenade
      orderObjTransform = human_context_command__pointObjTransform_ThrowGrenade

    human_context_command__pointObjTransform = orderObjTransform

    if orderObjName == ""
      return
    human_context_command__pointObjEid = createEntity(human_context_command__pointObjTemplate) <| $(var init : ComponentsInitializer)
      init |> set(human_context_command__pointObjResCompName, orderObjName)
      init |> set("previewIconOffsetY", orderIconOffsetY)
      var tm : float3x4
      human_point_obj_make_tm(tm, human_context_command__pointOrderPos, human_context_command__pointOrderDir, human_context_command__pointOrderNorm)
      init |> set("transform", tm * human_context_command__pointObjTransform)

def human_point_order_obj_update(human_eid : EntityId)
  query(human_eid) <| $ [es] (human_context_command__pointOrderPos : float3;
                              human_context_command__pointOrderAck : int;
                              human_context_command__pointOrderDir : float3;
                              human_context_command__pointOrderNorm : float3;
                              human_context_command__pointObjEid : EntityId;
                              human_context_command__pointObjTransform : float3x4)
    query(human_context_command__pointObjEid) <| $ [es] (var transform : float3x4&)
      var tm : float3x4
      human_point_obj_make_tm(tm, human_context_command__pointOrderPos, human_context_command__pointOrderDir, human_context_command__pointOrderNorm)
      transform = tm * human_context_command__pointObjTransform

    query() <| $ [es] (var semi_transparent__placingColor : float3&; placingColor__good : float3; placingColor__bad : float3)
      if human_context_command__pointOrderAck > 0
        semi_transparent__placingColor = placingColor__good
      else
        semi_transparent__placingColor = placingColor__bad

def human_point_order_obj_destroy(human_eid : EntityId)
  query(human_eid) <| $ [es] (var human_context_command__pointObjEid : EntityId&)
    if human_context_command__pointObjEid != INVALID_ENTITY_ID
      destroyEntity(human_context_command__pointObjEid)
      human_context_command__pointObjEid = INVALID_ENTITY_ID


def human_point_get_trace_pos_dir(human_eid : EntityId; var out_trace_pos : float3&; var out_trace_dir : float3&)
  return get_human_context_command_trace_pos_dir(human_eid, out_trace_pos, out_trace_dir)

struct HumanPointOrderTraced
  pos : float3 = float3()
  dir : float3 = float3()
  kind : int = -1
  eid : EntityId = INVALID_ENTITY_ID
  tracePos : float3 = float3()
  traceDir : float3 = float3()

def human_point_order_trace(human_eid : EntityId; order_type : int; var out_traced : HumanPointOrderTraced&)
  var tracePos, traceDir : float3
  let traceByHumanGun = order_type == int(HumanPointOrderType.POINT_DETECT_CONTEXT) ? human_eid : INVALID_ENTITY_ID
  if !get_human_context_command_trace_pos_dir(traceByHumanGun, tracePos, traceDir)
    return false
  return human_point_order_trace(human_eid, order_type, tracePos, traceDir, out_traced)

def human_point_order_trace(human_eid : EntityId; order_type : int;
                            trace_pos : float3; trace_dir : float3;
                            var out_traced : HumanPointOrderTraced&)
  out_traced.tracePos = trace_pos
  out_traced.traceDir = trace_dir

  if order_type == int(HumanPointOrderType.POINT_TAKE_POSITION)
    
    
    
    
    
    
    
    
    
    
    var pos : float3
    var res = false
    let activeTracing = true
    query() <| $ [es(REQUIRE=human_context_point_order_common)] (var trace_mesh_faces : TraceMeshFaces?)
      if trace_human_context_command_order_pos(pos, human_eid, trace_pos, trace_dir, activeTracing, trace_mesh_faces)
        out_traced.pos = pos
        out_traced.dir = float3()
        out_traced.kind = int(HumanPointTargetKind.NONOBJ)
        out_traced.eid = INVALID_ENTITY_ID
        res = true
    return res

  if order_type == int(HumanPointOrderType.POINT_DETECT_CONTEXT)
    var objDist : float
    let objEid = trace_human_context_command_first_ahead_object_eid(human_eid, trace_pos, trace_dir, objDist)

    if objEid != INVALID_ENTITY_ID
      out_traced.pos = trace_pos + trace_dir * objDist
      out_traced.dir = float3()
      if objEid |> has("human_net_phys")
        out_traced.eid = INVALID_ENTITY_ID
        query(objEid) <| $ [es] (transform : float3x4)
          out_traced.pos = transform[3]
          out_traced.dir = float3()
          out_traced.kind = int(HumanPointTargetKind.HUMAN)
          out_traced.eid = objEid
        if out_traced.eid != INVALID_ENTITY_ID
          return true
      elif objEid |> get_bool("isDoor") ?? false
        out_traced.kind = int(HumanPointTargetKind.DOOR)
        out_traced.eid = objEid
        return true
      elif objEid |> has("destroyable_wall")
        out_traced.kind = int(HumanPointTargetKind.DESTROYABLE_WALL)
        out_traced.eid = objEid
        return true
      elif objEid |> has("unit_tag__tank") || objEid |> has("unit_tag__aircraft")
        out_traced.kind = int(HumanPointTargetKind.VEHICLE)
        out_traced.eid = objEid
        return true

    
    
    
    
    
    
    
    
    
    

    if objDist != FLT_MAX
      out_traced.pos = trace_pos + trace_dir * objDist
      out_traced.dir = float3()
      out_traced.kind = int(HumanPointTargetKind.NONOBJ)
      out_traced.eid = INVALID_ENTITY_ID
      return true
    return false

  if (order_type == int(HumanPointOrderType.POINT_THROW_FRAG_GRENADE) ||
      order_type == int(HumanPointOrderType.POINT_THROW_SMOKE_GRENADE) ||
      order_type == int(HumanPointOrderType.POINT_THROW_FLASH_GRENADE))
    out_traced.pos = float3()
    out_traced.dir = float3()
    out_traced.kind = int(HumanPointTargetKind.NONOBJ)
    out_traced.eid = INVALID_ENTITY_ID
    var pos : float3
    var dir : float3
    if trace_human_context_command_grenade_pos(pos, dir, true, human_eid, trace_pos, trace_dir)
      out_traced.pos = pos
      out_traced.dir = dir
      return true
    return false

  return false

def human_point_order_trace_spot(human_eid : EntityId; order_type : int; var out_traced : HumanPointOrderTraced&)
  var tracePos, traceDir : float3
  if !get_human_context_command_trace_pos_dir(human_eid, tracePos, traceDir)
    return false

  let traceRight = normalize(cross(float3(0, 1, 0), traceDir))
  let traceUp = cross(traceDir, traceRight)

  let MAX_RADIUS_STEPS = 10
  let RADIUS_STEP = deg_to_rad(0.2)
  let CIRCLE_SPLIT = deg_to_rad(0.5)

  var hasTraced = false
  var hasNonObj = false
  out_traced = HumanPointOrderTraced()

  for i in range(MAX_RADIUS_STEPS)
    let rad = float(i) * RADIUS_STEP
    let numPoints = ((int(ceil((TWOPI * rad) / CIRCLE_SPLIT))) / 2 + 1) * 2
    for j in range(numPoints)
      let ang = float(j) * TWOPI / float(numPoints)
      var sinAng, cosAng : float
      sincos(ang, sinAng, cosAng)
      let tpos = tracePos
      let tdir = normalize(traceDir + rad * (traceUp * sinAng - traceRight * cosAng))
      var subTraced = HumanPointOrderTraced()
      
      if !human_point_order_trace(human_eid, order_type, tpos, tdir, subTraced)
        continue
      let isObj = subTraced.kind != int(HumanPointTargetKind.NONOBJ)
      if !hasTraced && !isObj
        hasNonObj = true
        out_traced = subTraced
      if isObj
        hasTraced = true
        out_traced = subTraced
        break
    if hasTraced
      break
  if !hasTraced && hasNonObj
    out_traced.tracePos = tracePos
    out_traced.traceDir = traceDir
  return hasTraced || hasNonObj


def human_point_order_dir_by_angle(base_dir : float3; norm : float3; rotate_angle : float)
  let forw = base_dir
  let right = float3(base_dir.z, 0.0, -base_dir.x)
  var dirSin, dirCos : float
  sincos(rotate_angle, dirSin, dirCos)
  var dir = forw * dirCos + right * dirSin
  dir -= dot(dir, norm) * norm
  return normalize(dir)

def private is_too_close_to_other_squad_members(pos : float3; soldier_eid : EntityId)
  var result = false
  let MIN_DIST_BETWEEN_MEMBERS_POSITIONS = 0.4
  let minDistSq = square(MIN_DIST_BETWEEN_MEMBERS_POSITIONS)
  query(soldier_eid) <| $ [es] (squad_member__squad : EntityId)
    query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
      for memberEid in squad__allMembers
        if memberEid != soldier_eid
          var memberPos = float3()
          query(memberEid) <| $ [es] (transform : float3x4; squad_member__orderType : int = 0; squad_member__orderPosition : float3 = float3())
            memberPos = transform[3]
            if is_squad_mate_order_positional(squad_member__orderType)
              memberPos = squad_member__orderPosition
            if distance_sq(memberPos, pos) < minDistSq
              result = true
          if result
            break
  return result

def validate_human_point_order_pos(order_type : int; mate_eid : EntityId; var pos : float3&; soldier_eid : EntityId; leader_dir : float3)
  if order_type == int(HumanPointOrderType.POINT_TAKE_POSITION)
    if mate_eid != INVALID_ENTITY_ID
      return 2
    if !validate_human_context_command_pos(pos, soldier_eid)
      return 0
    if is_too_close_to_other_squad_members(pos, soldier_eid)
      let forw = normalize(x0z(leader_dir))
      let rght = float3(forw.z, 0.0, -forw.x)
      let MAX_TURNS = 8
      let ANG_COEF = TWOPI / float(MAX_TURNS)
      let RADIUS_AROUND = 1.0
      for i in range(MAX_TURNS)
        let ang = float(i) * ANG_COEF
        var sinAng, cosAng : float
        sincos(ang, sinAng, cosAng)
        let posAround = pos + RADIUS_AROUND * (forw * sinAng + rght * cosAng)
        if validate_human_context_command_pos(posAround, soldier_eid) && !is_too_close_to_other_squad_members(posAround, soldier_eid)
          pos = posAround
          return 1
      return 0
    return 1
  return 2


def private human_point_order_get_positional_order(pose : int; subtype : int; var out_order : int&)
  if subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH)
    if pose == int(HumanPointOrderPose.STANDING)
      out_order = int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING)
    elif pose == int(HumanPointOrderPose.CROUCHED)
      out_order = int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED)
    elif pose == int(HumanPointOrderPose.PRONE)
      out_order = int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE)
  elif subtype == int(HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_UP)
    out_order = int(SquadMateOrder.ESMO_PEEKOUT_STAND_UP)
  elif human_point_order_is_peekout_subtype(subtype)
    if pose == int(HumanPointOrderPose.STANDING)
      out_order = int(SquadMateOrder.ESMO_PEEKOUT_STANDING)
    elif pose == int(HumanPointOrderPose.CROUCHED)
      out_order = int(SquadMateOrder.ESMO_PEEKOUT_CROUCHED)


def private human_point_order_try_find_peekout_position(var in_out_pos : float3&; var out_dir : float3&; var out_cover_pos : float3&; trace_params : TraceSightDistanceParams;
                                                        forw_pos : float3; forw_dir : float3; look_dir : float3; look_corner_dist : float; var trace_handle : TraceMeshFaces&)
  let PEEKOUT_LEAN_DIST = 0.2
  let PEEKOUT_LOOK_CORNER_DIST = 3.0
  let PEEKOUT_SEARCH_DIST = 0.6
  let MIN_PEEKOUT_SEARCH_POS = in_out_pos - forw_dir * PEEKOUT_SEARCH_DIST
  let MAX_PEEKOUT_SEARCH_POS = in_out_pos + forw_dir * PEEKOUT_SEARCH_DIST
  let MAX_TRIES = 7
  let FROM_WALL_DIST = 0.4

  
  
  
  

 
  var tries = 0
  var bestPeekoutPos = float3()
  var interpK = 0.5
  var interpKChanges = 1
  let peekoutSightTargetPos = forw_pos + look_dir * look_corner_dist
  while tries < MAX_TRIES
    let peekoutHumanPos = lerp(MIN_PEEKOUT_SEARCH_POS, MAX_PEEKOUT_SEARCH_POS, interpK)
    let peekoutSightPos = peekoutHumanPos + forw_dir * PEEKOUT_LEAN_DIST

    let peekoutLookDir = normalize(x0z(peekoutSightTargetPos - peekoutSightPos))
    let peekoutSightDist = trace_human_context_command_sight_distance(trace_params, peekoutSightPos, peekoutLookDir, PEEKOUT_LOOK_CORNER_DIST, HumanPointOrderHeightOfSight.CROUCHED, trace_handle, 0.1)
    if peekoutSightDist < 0.0
      
      bestPeekoutPos = peekoutHumanPos
    
      
    interpK += (peekoutSightDist < 0.0 ? -1.0 : 1.0) * pow(0.5, float(interpKChanges + 1))
    tries++
    interpKChanges++

  if bestPeekoutPos == float3()
    return false

  let peekoutLookDir = normalize(x0z(peekoutSightTargetPos - bestPeekoutPos))
  let toWallDist = trace_human_context_command_sight_distance(trace_params, bestPeekoutPos, peekoutLookDir, 0.5, HumanPointOrderHeightOfSight.CROUCHED, trace_handle)
  if toWallDist < 0.0
    bestPeekoutPos -= peekoutLookDir * FROM_WALL_DIST
  else
    bestPeekoutPos += peekoutLookDir * (toWallDist - FROM_WALL_DIST)

  
  let DIST_TO_COVER = 0.45
  let DIST_TO_COVER_WALL_CHECK = 0.9
  let COVER_DIST_TO_WALL = 1.0
  var toCoverDir = float3(-peekoutLookDir.z, 0.0, peekoutLookDir.x)
  if dot(toCoverDir, forw_dir) > 0.0
    toCoverDir = -toCoverDir

  let coverWallPos = bestPeekoutPos + toCoverDir * DIST_TO_COVER_WALL_CHECK
  let checkCoverWallDist = trace_human_context_command_sight_distance(trace_params, coverWallPos, peekoutLookDir, COVER_DIST_TO_WALL, HumanPointOrderHeightOfSight.CROUCHED, trace_handle, 0.15)
  if checkCoverWallDist < 0.0
    
    return false

  let toCoverPos = bestPeekoutPos + toCoverDir * DIST_TO_COVER
  let toWallDistCover = trace_human_context_command_sight_distance(trace_params, toCoverPos, peekoutLookDir, COVER_DIST_TO_WALL, HumanPointOrderHeightOfSight.CROUCHED, trace_handle, 0.15)
  if toWallDistCover < 0.0
    
    return false
  let coverPos = toCoverPos + peekoutLookDir * (toWallDistCover - FROM_WALL_DIST)
  

  in_out_pos = bestPeekoutPos
  out_dir = peekoutSightTargetPos - bestPeekoutPos
  out_cover_pos = coverPos

  return true

def human_point_order_start(human_eid : EntityId; pos : float3; kind : int; obj_eid : EntityId; point_order_type : int; for_eid : EntityId) : bool
  var result = false
  query(human_eid) <| $ [es] (var human_context_command__pointOrder : int&;
                              var human_context_command__pointOrderSubtype : int&;
                              var human_context_command__pointOrderOutType : int&;
                              var human_context_command__pointOrderTimeout : float&;
                              var human_context_command__pointOrderPos : float3&;
                              var human_context_command__pointOrderAck : int&;
                              var human_context_command__pointOrderNorm : float3&;
                              var human_context_command__pointOrderDir : float3&;
                              var human_context_command__pointOrderToPos : float3&;
                              var human_context_command__pointOrderToDir : float3&;
                              var human_context_command__pointOrderPose : int&;
                              var human_context_command__pointOrderBaseDir : float3&;
                              var human_context_command__pointOrderRotateAngle : float&;
                              var human_context_command__pointOrderRotateAngleLastPos : float3&;
                              var human_context_command__pointOrderShowTime : float&;
                              var human_context_command__pointOrderForKind : int&;
                              var human_context_command__pointOrderAutoToPos : float3&;
                              var human_context_command__correctPosCurrentTurn : int&;
                              team aka human_team : int = TEAM_UNASSIGNED;
                              transform aka human_transform : float3x4;
                              human_context_command__pointOrderRotateAngleMaxDist : float = 1.0;
                              human_context_command__pointOrderTimeoutTime : float = 1.0)
    human_context_command__pointOrder = point_order_type
    human_context_command__pointOrderTimeout = get_sync_time() + human_context_command__pointOrderTimeoutTime
    human_context_command__pointOrderPos = pos
    human_context_command__pointOrderNorm = float3(0, 1, 0)

    let mateEid = kind == int(HumanPointTargetKind.HUMAN) ? obj_eid : INVALID_ENTITY_ID
    human_context_command__pointOrderAck = validate_human_point_order_pos(human_context_command__pointOrder, mateEid, human_context_command__pointOrderPos, for_eid, human_transform[0])

    var dir = float3(1, 0, 0)
    query(human_eid) <| $ [es] (transform : float3x4)
      dir = normalize(pos - transform[3])

    human_context_command__pointOrderDir = dir
    human_context_command__pointOrderBaseDir = dir
    human_context_command__pointOrderRotateAngle = 0.0
    human_context_command__pointOrderRotateAngleLastPos = float3()
    human_context_command__pointOrderPose = int(HumanPointOrderPose.CROUCHED)
    human_context_command__pointOrderToPos = float3()
    human_context_command__pointOrderToDir = float3()
    human_context_command__pointOrderOutType = int(SquadMateOrder.ESMO_NO_ORDER)
    human_context_command__pointOrderSubtype = -1

    human_context_command__correctPosCurrentTurn = 0

    if mateEid != INVALID_ENTITY_ID
      let DELAY_ORDER = 0.3
      human_context_command__pointOrderShowTime = get_sync_time() + DELAY_ORDER

      let curStance = STANCE_CROUCH 
      if curStance == STANCE_STAND
        human_context_command__pointOrderPose = int(HumanPointOrderPose.STANDING)
      elif curStance == STANCE_CRAWL
        human_context_command__pointOrderPose = int(HumanPointOrderPose.PRONE)

      let curDir = float3(1, 0, 0) 
      if curDir != float3()
        human_context_command__pointOrderDir = curDir
        human_context_command__pointOrderBaseDir = curDir
        human_context_command__pointOrderForKind = kind
        human_context_command__pointOrderAutoToPos = human_point_order_get_overwatch_auto_look_point(human_context_command__pointOrderPos, human_team)
        var orderInfo : PositionalOrderInfo
        human_point_order_update_positional_order(human_eid, human_context_command__pointOrderRotateAngle, orderInfo, human_context_command__pointOrderRotateAngleLastPos,
                                              human_context_command__pointOrderRotateAngleMaxDist, human_context_command__pointOrderPos,
                                              human_context_command__pointOrderBaseDir, human_context_command__pointOrderAutoToPos,
                                              int(human_context_command__pointOrderPose))

      human_point_order_obj_destroy(human_eid)
    else
      human_context_command__pointOrderShowTime = -1.0
      human_context_command__pointOrderForKind = kind
      human_context_command__pointOrderAutoToPos = human_point_order_get_overwatch_auto_look_point(human_context_command__pointOrderPos, human_team)
      var orderInfo : PositionalOrderInfo
      human_point_order_update_positional_order(human_eid, human_context_command__pointOrderRotateAngle, orderInfo, human_context_command__pointOrderRotateAngleLastPos,
                                            human_context_command__pointOrderRotateAngleMaxDist, human_context_command__pointOrderPos,
                                            human_context_command__pointOrderBaseDir, human_context_command__pointOrderAutoToPos,
                                            int(human_context_command__pointOrderPose))
      human_point_order_obj_recreate(human_eid)
    result = true
  return result


def private human_point_order_get_overwatch_auto_look_point(from_pos : float3; our_team : int)
  let MIN_DIST = 5.0
  let minDistSq = square(MIN_DIST)
  var sumPoints = float3()
  var numPoints = 0.0
  get_respawn_points() <| $ [unused_argument(respType)] (active, respType, team, respPos)
    if active && team != our_team && distance_sq(respPos, from_pos) > minDistSq
      sumPoints += respPos
      numPoints += 1.0
  if numPoints <= 0.0
    return float3()
  return sumPoints * rcp(numPoints)

def private human_point_order_correct_positional_order(human_eid : EntityId; from_pos : float3; to_pos : float3; base_dir : float3; pose : int;
                                                       var current_turn_counter : int&;
                                                       var high_traces_dists : FloatList&;
                                                       var trace_handle : TraceMeshFaces&)
  var leaderPos = float3()
  query(human_eid) <| $ [es] (transform : float3x4)
    leaderPos = transform[3]
  var traceParams : TraceSightDistanceParams
  traceParams.humanEid = human_eid
  get_human_context_order_trace_params(human_eid, traceParams.maxDist, traceParams.rayMatId)

  let dir = normalize(x0z(to_pos - from_pos))
  let rtDir = float3(dir.z, 0.0, -dir.x)

  let MAX_FARS = 6
  let TURN_FARS = deg_to_rad(5.0)

  let MAX_TURNS = 36
  let TURN_RAD = deg_to_rad(10.0)

  let currentTurn = current_turn_counter
  current_turn_counter = (current_turn_counter + 1) % MAX_TURNS

  let MIN_SIGHT_DIST = 1.5
  let MAX_SIGHT_DIST = 10.0
  let FAR_SIGHT_DIST = 10.0

  let MAX_FORW_STEPS = 7
  let FORW_STEP_LENGTH = 0.5
  let FORW_CHECK_MAX_DIST = float(MAX_FORW_STEPS) * FORW_STEP_LENGTH + 0.01
  let LOOK_CORNER_DIST = 2.0
  let MAX_NEAR_WALL = MAX_TURNS / 5
  let CLOSE_TO_WALL_DIST = 1.0
  let FROM_WALL_DIST = 0.1
  let PEEKOUT_STAND_UP_MAX_TO_WALL_DIST = 0.8
  let PEEKOUT_STAND_UP_LOOK_DIST = 2.5
  let PEEKOUT_COVER_SIGHT_RADIUS = 0.1
  let PEEKOUT_COVER_SIDE_OFFSET = 0.35

  let FORW_TRACE_DIST = max(MIN_SIGHT_DIST, FORW_CHECK_MAX_DIST)

  let NO_BACK_DIST = 3.0
  let NO_BACK_DIST_SQ = square(NO_BACK_DIST)
  let COS_BACK_ANG = cos(deg_to_rad(45.0))

  var froms : array<float3>
  var dists : array<float>
  var dirs : array<float3>
  froms |> resize(MAX_TURNS)
  dists |> resize(MAX_TURNS)
  dirs |> resize(MAX_TURNS)

  
  for i in range(MAX_TURNS)
    let ang = float(i) * TURN_RAD
    var sinAng, cosAng : float
    sincos(ang, sinAng, cosAng)

    let BACK_DIST = 0.1
    let rdir = dir * cosAng + rtDir * sinAng
    let fromPos = from_pos - rdir * BACK_DIST
    let dist = trace_human_context_command_sight_distance(traceParams, fromPos, rdir, FORW_TRACE_DIST, HumanPointOrderHeightOfSight.CROUCHED, trace_handle)

    froms[i] = fromPos
    dists[i] = dist
    dirs[i] = rdir

  
  if pose == int(HumanPointOrderPose.CROUCHED)
    var closestWallTurn = -1
    for i in range(MAX_TURNS)
      if dists[i] >= 0.0 && (closestWallTurn < 0 || dists[i] < dists[closestWallTurn])
        closestWallTurn = i
    if closestWallTurn >= 0 && dists[closestWallTurn] >= 0.0 && dists[closestWallTurn] < PEEKOUT_STAND_UP_MAX_TO_WALL_DIST
      let standingLookDist = trace_human_context_command_sight_distance(traceParams, from_pos, dirs[closestWallTurn], PEEKOUT_STAND_UP_LOOK_DIST, HumanPointOrderHeightOfSight.PEEKOUT_STANDING_UP, trace_handle)
      if standingLookDist < 0.0
        let coverLookDist = trace_human_context_command_sight_distance(traceParams, from_pos, dirs[closestWallTurn], CLOSE_TO_WALL_DIST, HumanPointOrderHeightOfSight.PEEKOUT_CROUCHED_COVER, trace_handle, PEEKOUT_COVER_SIGHT_RADIUS)
        if coverLookDist >= 0.0
          let leftDir = normalize(float3(-dirs[closestWallTurn].z, 0.0, dirs[closestWallTurn].x))
          let leftCoverPos = from_pos + leftDir * PEEKOUT_COVER_SIDE_OFFSET
          let rightCoverPos = from_pos - leftDir * PEEKOUT_COVER_SIDE_OFFSET
          let coverLeftDist = trace_human_context_command_sight_distance(traceParams, leftCoverPos, dirs[closestWallTurn], CLOSE_TO_WALL_DIST, HumanPointOrderHeightOfSight.PEEKOUT_CROUCHED_COVER, trace_handle, PEEKOUT_COVER_SIGHT_RADIUS)
          let coverRightDist = trace_human_context_command_sight_distance(traceParams, rightCoverPos, dirs[closestWallTurn], CLOSE_TO_WALL_DIST, HumanPointOrderHeightOfSight.PEEKOUT_CROUCHED_COVER, trace_handle, PEEKOUT_COVER_SIGHT_RADIUS)
          if coverLeftDist >= 0.0 && coverRightDist >= 0.0
            
            let inCoverDir = dot(leftDir, base_dir) > 0.0 ? leftDir : -leftDir
            return PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_UP, pos = from_pos, dir = dirs[closestWallTurn], toPos = from_pos, toDir = inCoverDir)

  
  var bestCorner = -1
  var bestCornerDist = 0.0
  var bestPeekoutPos = float3()
  var bestPeekoutCoverPos = float3()
  var bestPeekoutDir = float3()
  var foundPeekoutTurn = -1
  for i in range(MAX_TURNS)
    
    if dists[i] < 0.0 || dists[i] > MIN_SIGHT_DIST
      
      
      var checkDir = i
      var checkLeft = -1
      var checkRight = -1
      for j in range(MAX_NEAR_WALL)
        let prevJ = (i + MAX_TURNS - j - 1) % MAX_TURNS
        let distP = dists[prevJ]
        if distP < 0.0 || distP > MIN_SIGHT_DIST
          break
        if distP < CLOSE_TO_WALL_DIST
          var cnt = 3
          while dists[checkDir] >= 0.0 && cnt > 0
            let nextJ = (checkDir + 1) % MAX_TURNS
            if dists[nextJ] >= 0.0 && dists[nextJ] < dists[checkDir]
              break
            checkDir = nextJ
            --cnt
          checkRight = prevJ
          break
      for j in range(MAX_NEAR_WALL)
        let nextJ = (i + j + 1) % MAX_TURNS
        let distN = dists[nextJ]
        if distN < 0.0 || distN > MIN_SIGHT_DIST
          break
        if distN < CLOSE_TO_WALL_DIST
          var cnt = 3
          while dists[checkDir] >= 0.0 && cnt > 0
            let prevJ = (checkDir + MAX_TURNS - 1) % MAX_TURNS
            if dists[prevJ] >= 0.0 && dists[prevJ] < dists[checkDir]
              break
            checkDir = prevJ
            --cnt
          checkLeft = nextJ
          break

      for turnRight in range(2)
        if (turnRight == 0 && checkLeft < 0) || (turnRight == 1 && checkRight < 0)
          continue

        
        
        
        
        

        let forwDir = dirs[checkDir]
        let lookDir = float3(forwDir.z, 0.0, -forwDir.x) * (turnRight > 0 ? -1.0 : 1.0)
        let fromPos = froms[checkDir] - lookDir * FROM_WALL_DIST
        let maxDist = min(dists[checkDir] < 0.0 ? FORW_TRACE_DIST : dists[checkDir], FORW_CHECK_MAX_DIST)
        
        
        for j in range(MAX_FORW_STEPS)
          let stepDist = float(1 + j) * FORW_STEP_LENGTH
          if stepDist > maxDist
            break
          let forwPos = fromPos + forwDir * stepDist
          let lookDist = trace_human_context_command_sight_distance(traceParams, forwPos, lookDir, LOOK_CORNER_DIST, HumanPointOrderHeightOfSight.CROUCHED, trace_handle)
          
          if lookDist < 0.0
            if foundPeekoutTurn == -1 || foundPeekoutTurn == i
              var peekoutHumanPos = fromPos
              var peekoutCoverPos : float3
              var peekoutDir : float3
              let hasPeekout = human_point_order_try_find_peekout_position(peekoutHumanPos, peekoutDir, peekoutCoverPos, traceParams, forwPos, forwDir, lookDir, LOOK_CORNER_DIST, trace_handle)
              if hasPeekout
                let leaderDirPeekoutProj = dot(peekoutDir, from_pos - leaderPos)
                if leaderDirPeekoutProj > 0.0 && (bestPeekoutPos == float3() || leaderDirPeekoutProj > dot(bestPeekoutDir, from_pos - leaderPos))
                  bestPeekoutPos = peekoutHumanPos
                  bestPeekoutCoverPos = peekoutCoverPos
                  bestPeekoutDir = peekoutDir
                  foundPeekoutTurn = i
                  
                break
            else
              bestPeekoutPos = float3()
            if bestCorner < 0 || stepDist < bestCornerDist
              let bestI = (dists[i] >= 0.0 && dists[i] < 1.0) ? checkDir : i
              var ok = true
              if leaderPos != float3() && distance_sq(leaderPos, fromPos) < NO_BACK_DIST_SQ
                let chk = dot(dirs[bestI], base_dir)
                if chk < -COS_BACK_ANG
                  ok = false
              if ok
                bestCorner = bestI
                bestCornerDist = stepDist
                break
  if bestPeekoutPos != float3()
    let peekoutDirLeft = float3(-bestPeekoutDir.z, 0, bestPeekoutDir.x)
    let peekoutWalkDir = normalize(x0z(bestPeekoutPos - bestPeekoutCoverPos))
    let orderType = dot(peekoutWalkDir, peekoutDirLeft) > 0.0 ? HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_LEFT : HumanPointOrderSubtype.POINT_TAKE_POSITION_PEEKOUT_RIGHT
    return PositionalOrderInfo(subtype = orderType, pos = bestPeekoutPos, dir = bestPeekoutDir, toPos = bestPeekoutCoverPos, toDir = peekoutWalkDir)
  if bestCorner >= 0
    let pt = froms[bestCorner] + dirs[bestCorner] * (dists[bestCorner] < 0.0 ? MIN_SIGHT_DIST : dists[bestCorner])
    let orderDir = pt - from_pos
    return PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = orderDir)

  
  var farSightRes : PositionalOrderInfo
  var foundFarSight = false
  using() <| $(var far_sight_trace_handle : TraceMeshFaces)
    var traceHandleBbox : bbox3f
    let traceHandleHeight = match_height_of_sight(HumanPointOrderHeightOfSight.STANDING)
    let traceHandlePos = from_pos + dir * FAR_SIGHT_DIST * 0.7 + float3(0.0, traceHandleHeight, 0.0)
    traceHandleBbox.bmax.xyz = traceHandlePos + float3(FAR_SIGHT_DIST * 0.75, 1.2, FAR_SIGHT_DIST * 0.75)
    traceHandleBbox.bmin.xyz = traceHandlePos + float3(-FAR_SIGHT_DIST * 0.75, -0.2, -FAR_SIGHT_DIST * 0.75)
    let traceHandleExpands = float3(0.1, 0.1, 0.1)
    let physmapExpands = FAR_SIGHT_DIST * 0.5
    validate_trace_cache(traceHandleBbox, traceHandleExpands, physmapExpands, far_sight_trace_handle)

    for i in range(MAX_FARS)
      let ang = float(i) * TURN_FARS
      var sinAng, cosAng : float
      sincos(ang, sinAng, cosAng)
      let rdir1 = dir * cosAng + rtDir * sinAng
      let dist1 = trace_human_context_command_sight_distance(traceParams, from_pos, rdir1, FAR_SIGHT_DIST, HumanPointOrderHeightOfSight.STANDING, far_sight_trace_handle)
      if dist1 < 0.0
        
        
        farSightRes = PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = rdir1)
        foundFarSight = true
        return
      if i == 0
        continue
      let rdir2 = dir * cosAng - rtDir * sinAng
      let dist2 = trace_human_context_command_sight_distance(traceParams, from_pos, rdir2, FAR_SIGHT_DIST, HumanPointOrderHeightOfSight.STANDING, far_sight_trace_handle)
      if dist2 < 0.0
        
        
        farSightRes = PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = rdir2)
        foundFarSight = true
        return

    let DIR_UP = float3(0.0, 0.1, 0.0)
    for i in range(MAX_FARS)
      let ang = float(i) * TURN_FARS
      var sinAng, cosAng : float
      sincos(ang, sinAng, cosAng)
      let rdir1 = normalize(dir * cosAng + rtDir * sinAng + DIR_UP)
      let dist1 = trace_human_context_command_sight_distance(traceParams, from_pos, rdir1, FAR_SIGHT_DIST, HumanPointOrderHeightOfSight.STANDING, far_sight_trace_handle)
      if dist1 < 0.0
        
        
        farSightRes = PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = rdir1)
        foundFarSight = true
        return
      if i == 0
        continue
      let rdir2 = normalize(dir * cosAng - rtDir * sinAng + DIR_UP)
      let dist2 = trace_human_context_command_sight_distance(traceParams, from_pos, rdir2, FAR_SIGHT_DIST, HumanPointOrderHeightOfSight.STANDING, far_sight_trace_handle)
      if dist2 < 0.0
        
        
        farSightRes = PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = rdir2)
        foundFarSight = true
        return

  if foundFarSight
    return farSightRes

  
  if pose != int(HumanPointOrderPose.PRONE)
    let turn = currentTurn % MAX_TURNS
    var ang = float(turn) * TURN_RAD
    var sinAng, cosAng : float
    sincos(ang, sinAng, cosAng)
    let BACK_DIST = 0.1
    var rdir = dir * cosAng + rtDir * sinAng
    var fromPos = from_pos - rdir * BACK_DIST
    let traceDist = trace_human_context_command_sight_distance(traceParams, fromPos, rdir, MAX_SIGHT_DIST, HumanPointOrderHeightOfSight.STANDING, trace_handle)
    if length(high_traces_dists) != MAX_TURNS
      high_traces_dists |> resize(MAX_TURNS)
      for dist in high_traces_dists
        dist = 0.0
    high_traces_dists[turn] = traceDist

    for i in range(MAX_TURNS)
      ang = float(i) * TURN_RAD
      sincos(ang, sinAng, cosAng)

      rdir = dir * cosAng + rtDir * sinAng
      fromPos = from_pos - rdir * BACK_DIST
      let dist = high_traces_dists[i]
      froms[i] = fromPos
      dists[i] = dist
      dirs[i] = rdir

      
      

  
  
  
  
  
  
  
  
  
  

  
  
  
  
  

  
  var anyLongStart = -1
  for i in range(MAX_TURNS)
    if dists[i] < 0.0
      anyLongStart = i
      break
  if anyLongStart >= 0
    var prevLongStart = -1
    for i in range(MAX_TURNS)
      let j = (anyLongStart + MAX_TURNS - i) % MAX_TURNS
      if dists[j] >= 0.0
        break
      prevLongStart = j
    if prevLongStart == (anyLongStart + 1) % MAX_TURNS
      let bestDist = dists[0] < 0.0 ? MAX_SIGHT_DIST : dists[0]
      let orderDir = (froms[0] + dirs[0] * bestDist) - from_pos
      return PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = orderDir)
    elif prevLongStart >= 0
      anyLongStart = prevLongStart

  
  if anyLongStart >= 0
    var longs : array<int>
    var longsLens : array<int>
    longs |> reserve(MAX_TURNS / 2)
    longsLens |> reserve(MAX_TURNS / 2)
    var bestLong = anyLongStart
    var bestLongLen = 1
    var longStart = -1
    var longLen = 0
    for i in range(MAX_TURNS * 2)
      let dist = dists[i % MAX_TURNS]
      if dist < 0.0
        if longStart < 0
          longStart = i
          longLen = 1
          longs |> push(i)
          longsLens |> push(1)
        else
          longLen++
          longsLens[length(longsLens) - 1] = longLen
          if longLen > bestLongLen
            bestLong = longStart
            bestLongLen = longLen
      else
        longStart = -1
        longLen = 0
    if bestLong >= 0
      if length(longs) > 3
        var bestTurn = 0
        var bestDot = -1.0
        for i in range(MAX_TURNS)
          if dists[i] < 0.0
            let dirDot = dot(dirs[i], dir)
            if dirDot > bestDot
              bestTurn = i
              bestDot = dirDot
        let bestDist = dists[bestTurn] < 0.0 ? MAX_SIGHT_DIST : dists[bestTurn]
        let orderDir = (froms[bestTurn] + dirs[bestTurn] * bestDist) - from_pos
        return PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = orderDir)

      var bestBestLong = -1
      var bestBestScore = 0.0
      for i in iter_range(longs)
        if abs(longsLens[i] - bestLongLen) <= 1
          let iStart = longs[i] % MAX_TURNS
          let iLen = longsLens[i]
          let distP = dists[(iStart + MAX_TURNS - 1) % MAX_TURNS]
          let distN = dists[(iStart + iLen) % MAX_TURNS]
          let score = max(distP, distN)
          if bestBestLong < 0 || score < bestBestScore
            bestBestLong = i
            bestBestScore = score
      if bestBestLong >= 0
        let bestTurn = (longs[bestBestLong] + longsLens[bestBestLong] / 2) % MAX_TURNS
        let bestDist = dists[bestTurn] < 0.0 ? MAX_SIGHT_DIST : dists[bestTurn]
        let orderDir = (froms[bestTurn] + dirs[bestTurn] * bestDist) - from_pos
        return PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = from_pos, dir = orderDir)

  
  for i in range(MAX_TURNS)
    if dists[i] < 0.0
      dists[i] = MAX_SIGHT_DIST

  
  var bestTurn = 0
  var bestDist = MIN_SIGHT_DIST
  for i in range(MAX_TURNS)
    let dist = dists[i]
    if dist > bestDist
      bestTurn = i
      bestDist = dist

  return PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = froms[bestTurn], dir = dirs[bestTurn])

def private human_point_order_update_positional_order(human_eid : EntityId; var out_rotate_angle : float&; var out_order_info : PositionalOrderInfo&;
                                                      var inout_last_pos : float3&; reset_dist : float; pos : float3; base_dir : float3; look_pos : float3; pose : int)
  if inout_last_pos != float3()
    if distance_sq(pos, inout_last_pos) > square(reset_dist)
      inout_last_pos = float3()
    else
      out_order_info = PositionalOrderInfo(subtype = HumanPointOrderSubtype.POINT_TAKE_POSITION_OVERWATCH, pos = pos)
  if inout_last_pos == float3()
    out_rotate_angle = 0.0
    let INSIDE_SIM_LOOK_POS_DIST = 50.0
    let lookPos = look_pos != float3() ? look_pos : (pos + base_dir * INSIDE_SIM_LOOK_POS_DIST)
    query(human_eid) <| $ [es] (human_context_command__correctPosResetDist : float;
                                var human_context_command__correctPosPosCached : float3&;
                                var human_context_command__correctPosCurrentTurn : int&;
                                var human_context_command__correctPosHighTracesDists : FloatList&)
      query() <| $ [es] (human_context_command__traceHandleResetDist : float;
                         var human_context_command__traceHandlePosCached : float3&;
                         var trace_mesh_faces : TraceMeshFaces&)
        if distance_sq(pos, human_context_command__correctPosPosCached) > square(human_context_command__correctPosResetDist)
          human_context_command__correctPosPosCached = pos
        if distance_sq(pos, human_context_command__traceHandlePosCached) > square(human_context_command__traceHandleResetDist)
          human_context_command__traceHandlePosCached = pos
          let crouchedHeight = match_height_of_sight(HumanPointOrderHeightOfSight.CROUCHED)
          let heightDiff = match_height_of_sight(HumanPointOrderHeightOfSight.STANDING) - match_height_of_sight(HumanPointOrderHeightOfSight.CROUCHED)
          let traceCachePos = pos + float3(0.0, crouchedHeight + heightDiff * 0.5, 0.0)
          update_human_context_trace_cache(traceCachePos, 4.5, heightDiff * 0.5 + 2.0, trace_mesh_faces)
        out_order_info = human_point_order_correct_positional_order(human_eid, pos, lookPos, base_dir, pose,
                                                                    human_context_command__correctPosCurrentTurn,
                                                                    human_context_command__correctPosHighTracesDists,
                                                                    trace_mesh_faces)
    if out_order_info.dir != float3()
      let baseAngle = atan2(base_dir.z, base_dir.x)
      out_rotate_angle = baseAngle - atan2(out_order_info.dir.z, out_order_info.dir.x)


def human_point_order_update(human_eid : EntityId; for_eid : EntityId) : bool
  var result = false
  query(human_eid) <| $ [es] (human_context_command__pointOrder : int;
                              var human_context_command__pointOrderSubtype : int&;
                              var human_context_command__pointOrderOutType : int&;
                              var human_context_command__pointOrderPos : float3&;
                              var human_context_command__pointOrderAck : int&;
                              var human_context_command__pointOrderNorm : float3&;
                              var human_context_command__pointOrderDir : float3&;
                              var human_context_command__pointOrderBaseDir : float3&;
                              var human_context_command__pointOrderTimeout : float&;
                              var human_context_command__pointOrderShowTime : float&;
                              var human_context_command__pointOrderToPos : float3&;
                              var human_context_command__pointOrderToDir : float3&;
                              var human_context_command__pointOrderRotateAngle : float&;
                              var human_context_command__pointOrderRotateAngleLastPos : float3&;
                              transform aka human_transform : float3x4;
                              human_context_command__pointOrderRotateAngleMaxDist : float = 1.0;
                              human_context_command__pointOrderPose : int;
                              human_context_command__pointOrderForKind : int;
                              human_context_command__pointOrderAutoToPos : float3;
                              human_context_command__pointOrderTimeoutTime : float = 1.0)
    if human_context_command__pointOrder <= int(HumanPointOrderType.NOT_POINT_ORDER)
      return

    if human_context_command__pointOrderShowTime >= 0.0 && get_sync_time() >= human_context_command__pointOrderShowTime
      human_context_command__pointOrderShowTime = -1.0
      human_point_order_obj_recreate(human_eid)

    var out_order = int(SquadMateOrder.ESMO_NO_ORDER)
    var out_subtype = -1
    var traced = HumanPointOrderTraced()
    if human_point_order_trace(human_eid, human_context_command__pointOrder, traced)
      human_context_command__pointOrderPos = traced.pos
      human_context_command__pointOrderNorm = float3(0, 1, 0)

      let mateEid = traced.kind == int(HumanPointTargetKind.HUMAN) ? traced.eid : INVALID_ENTITY_ID
      human_context_command__pointOrderAck = validate_human_point_order_pos(human_context_command__pointOrder, mateEid, human_context_command__pointOrderPos, for_eid, human_transform[0])

      if human_context_command__pointOrderForKind != int(HumanPointTargetKind.HUMAN)
        traced.dir = float3(1, 0, 0)
        query(human_eid) <| $ [es] (transform : float3x4)
          traced.dir = normalize(human_context_command__pointOrderPos - transform[3])
        human_context_command__pointOrderBaseDir = traced.dir

      let bdir = human_context_command__pointOrderBaseDir
      let norm = human_context_command__pointOrderNorm

      if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
        var orderInfo : PositionalOrderInfo
        human_point_order_update_positional_order(human_eid, human_context_command__pointOrderRotateAngle, orderInfo, human_context_command__pointOrderRotateAngleLastPos,
                                              human_context_command__pointOrderRotateAngleMaxDist, human_context_command__pointOrderPos,
                                              human_context_command__pointOrderBaseDir, human_context_command__pointOrderAutoToPos,
                                              int(human_context_command__pointOrderPose))

        human_point_order_get_positional_order(human_context_command__pointOrderPose, int(orderInfo.subtype), out_order)
        out_subtype = int(orderInfo.subtype)
        human_context_command__pointOrderPos = orderInfo.pos
        human_context_command__pointOrderDir = human_point_order_dir_by_angle(bdir, norm, human_context_command__pointOrderRotateAngle)
        human_context_command__pointOrderToPos = orderInfo.toPos
        human_context_command__pointOrderToDir = normalize(orderInfo.toDir)

      human_context_command__pointOrderTimeout = get_sync_time() + human_context_command__pointOrderTimeoutTime
      result = true
    elif is_human_point_order_await_shoot_accept(human_context_command__pointOrder)
      human_context_command__pointOrderDir = traced.dir
      human_context_command__pointOrderTimeout = get_sync_time() + human_context_command__pointOrderTimeoutTime
      result = false

    if out_order != human_context_command__pointOrderOutType || out_subtype != human_context_command__pointOrderSubtype
      human_context_command__pointOrderOutType = out_order
      human_context_command__pointOrderSubtype = out_subtype
      human_point_order_obj_recreate(human_eid)
  return result


def human_point_order_rotate_to_next_or_prev_dir(human_eid : EntityId; next : bool)
  var result = false
  query(human_eid) <| $ [es] (human_context_command__pointOrder : int;
                              human_context_command__pointOrderPos : float3;
                              human_context_command__pointOrderRotateAngleStep : float;
                              var human_context_command__pointOrderRotateAngle : float&;
                              var human_context_command__pointOrderRotateAngleLastPos : float3&)
    if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
      let rotateStep = deg_to_rad(human_context_command__pointOrderRotateAngleStep)
      let coef = next ? 1.0 : -1.0
      human_context_command__pointOrderRotateAngle += coef * rotateStep
      if human_context_command__pointOrderRotateAngle < -PI
        human_context_command__pointOrderRotateAngle += PI * 2.0
      elif human_context_command__pointOrderRotateAngle > PI
        human_context_command__pointOrderRotateAngle -= PI * 2.0
      human_context_command__pointOrderRotateAngleLastPos = human_context_command__pointOrderPos
      result = true
  return result

def human_point_order_change_to_next_or_prev_pose(human_eid : EntityId; next : bool)
  var result = false
  query(human_eid) <| $ [es] (human_context_command__pointOrder : int;
                              var human_context_command__pointOrderPose : int&)
    if human_context_command__pointOrder == int(HumanPointOrderType.POINT_TAKE_POSITION)
      result = true

      var pose = -1
      if human_context_command__pointOrderPose == int(HumanPointOrderPose.STANDING)
        pose = next ? int(HumanPointOrderPose.CROUCHED) : int(HumanPointOrderPose.PRONE)
      elif human_context_command__pointOrderPose == int(HumanPointOrderPose.CROUCHED)
        pose = next ? int(HumanPointOrderPose.PRONE) : int(HumanPointOrderPose.STANDING)
      elif human_context_command__pointOrderPose == int(HumanPointOrderPose.PRONE)
        pose = next ? int(HumanPointOrderPose.STANDING) : int(HumanPointOrderPose.CROUCHED)

      if pose != -1
        human_context_command__pointOrderPose = pose
        human_point_order_obj_recreate(human_eid)
  return result


def human_point_order_cancel(human_eid : EntityId)
  query(human_eid) <| $ [es] (var human_context_command__pointOrder : int&;
                              var human_context_command__pointObjEid : EntityId&)
    if human_context_command__pointObjEid != INVALID_ENTITY_ID
      destroyEntity(human_context_command__pointObjEid)
      human_context_command__pointObjEid = INVALID_ENTITY_ID
    human_context_command__pointOrder = int(HumanPointOrderType.NOT_POINT_ORDER)

def human_point_order_complete_simple(eid : EntityId)
  var order = -1
  var pos : float3
  var dir : float3
  var posTo : float3
  var dirTo : float3
  return human_point_order_complete(eid, order, pos, dir, posTo, dirTo)

def human_point_order_complete(human_eid : EntityId; var out_order : int&; var out_pos : float3&; var out_dir : float3&;
                               var out_pos_to : float3&; var out_dir_to : float3&)
  var finish = false
  query(human_eid) <| $ [es] (var human_context_command__pointOrder : int&;
                              var human_context_command__pointObjEid : EntityId&;
                              human_context_command__pointObjAnimTemplate : string;
                              human_context_command__pointObjAnimOffset : float3;
                              human_context_command__pointObjAnimTime : float)
    if human_context_command__pointOrder > int(HumanPointOrderType.NOT_POINT_ORDER)
      finish = true
      if human_context_command__pointObjEid != INVALID_ENTITY_ID && human_context_command__pointObjAnimTime > 0.0
        query(human_context_command__pointObjEid) <| $ [es] (transform : float3x4)
          createEntity(human_context_command__pointObjAnimTemplate) <| $(var init : ComponentsInitializer)
            init |> set("squad_point_animator__objectEid", human_context_command__pointObjEid)
            init |> set("squad_point_animator__sourcePos", transform[3])
            init |> set("squad_point_animator__targetPos", transform[3] + human_context_command__pointObjAnimOffset)
            init |> set("squad_point_animator__animTime", float2(get_sync_time(), human_context_command__pointObjAnimTime))
          human_context_command__pointObjEid = INVALID_ENTITY_ID

    if human_context_command__pointObjEid != INVALID_ENTITY_ID
      destroyEntity(human_context_command__pointObjEid)
      human_context_command__pointObjEid = INVALID_ENTITY_ID
    human_context_command__pointOrder = int(HumanPointOrderType.NOT_POINT_ORDER)

  var result = false

  if finish
    query(human_eid) <| $ [es] (human_context_command__pointOrderOutType : int;
                                human_context_command__pointOrderPos : float3;
                                human_context_command__pointOrderDir : float3;
                                human_context_command__pointOrderToPos : float3;
                                human_context_command__pointOrderToDir : float3;
                                human_context_command__pointOrderNorm : float3)
      let outType = human_context_command__pointOrderOutType
      let pos = human_context_command__pointOrderPos
      let dir = human_context_command__pointOrderDir
      let posTo = human_context_command__pointOrderToPos
      let dirTo = human_context_command__pointOrderToDir
      let norm = human_context_command__pointOrderNorm

      if outType > int(SquadMateOrder.ESMO_NO_ORDER)
        out_order = outType
        if is_squad_mate_order_peekout(outType)
          out_pos = posTo
          out_dir = dirTo
          out_pos_to = pos
          out_dir_to = dir
        else
          out_pos = pos
          out_dir = dir - dot(norm, dir) * norm
          out_pos_to = posTo
          out_dir_to = dirTo
        result = true

  return result


def human_context_command_menu_trace_throw_grenade(human_eid : EntityId; var out_pos : float3&; var out_dir : float3&; var out_alt_pos : float3&)
  var result = false
  query(human_eid) <| $ [es] (human_context_command__menuCtxPos : float3;
                              human_context_command__menuCtxType : string;
                              human_context_command__menuCtxTracePos : float3;
                              human_context_command__menuCtxTraceDir : float3)
    let ctxPos = human_context_command__menuCtxType != "" ? human_context_command__menuCtxPos : float3()
    var grenadePos = ctxPos
    var grenadeDir = float3()
    var grenadeAltPos = float3()
    if human_context_command__menuCtxTracePos != float3() && human_context_command__menuCtxTraceDir != float3()
      if trace_human_context_command_grenade_pos(grenadePos, grenadeDir, false, human_eid, human_context_command__menuCtxTracePos, human_context_command__menuCtxTraceDir)
        if grenadePos != float3() && grenadePos == grenadePos
          grenadeAltPos = ctxPos
        else
          grenadePos = ctxPos
          grenadeDir = float3()
    if grenadePos != float3()
      if grenadeDir == float3() && human_context_command__menuCtxTraceDir != float3()
        let OFFSET_FROM_WALL = 0.1
        grenadePos -= human_context_command__menuCtxTraceDir * OFFSET_FROM_WALL
    out_pos = grenadePos
    out_dir = grenadeDir
    out_alt_pos = grenadeAltPos
    result = grenadePos != float3()
  return result
