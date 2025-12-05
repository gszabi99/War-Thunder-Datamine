module bipod_common shared

require ecs
require ecs.safe
require math
require math.base
require math.ang
require Dacoll
require DagorMath
require DagorMathUtils
require AnimV20
require GeomNodeTree
require HumanPhys
require DngHuman
require GamePhys


def swap_xz(var tm : float3x4)
  let tmp = tm[0]
  tm[0] = -tm[2]
  tm[2] = tmp

def get_gun_tm(gunEid; var gunTm : float3x4) : bool
  var isGunFound = false
  query(gunEid) <| $ [es] (animchar : AnimcharBaseComponent)
    geomtree_getNodeWtmScalar(*animchar.nodeTree, 0, gunTm)
    swap_xz(gunTm)
    isGunFound = true
  return isGunFound

def calc_gun_tm(var gunTm; humanPhys; humanTm; gunPitch)
  human_phys_calcGunTm(humanPhys.phys, PrecomputedPresetMode.FPV, humanTm, gunPitch, humanPhys.phys.currentState.leanPosition, humanPhys.phys.currentState.height, gunTm)

def calc_fpv_gun_pos_for_height(var humanPhys; humanTm; gunPitch; height) : float3
  var gunTm : float3x4
  let wasOffset = humanPhys.phys.gunOffset
  humanPhys.phys.gunOffset = float3()
  human_phys_calcGunTm(humanPhys.phys, PrecomputedPresetMode.FPV, humanTm, gunPitch, humanPhys.phys.currentState.leanPosition, height, gunTm)
  humanPhys.phys.gunOffset = wasOffset
  return gunTm[3]

def calc_tpv_gun_pos_for_height(var humanPhys; humanTm; gunPitch; height) : float3
  var gunTm : float3x4
  let wasOffset = humanPhys.phys.gunOffset
  humanPhys.phys.gunOffset = float3()
  human_phys_calcGunTm(humanPhys.phys, PrecomputedPresetMode.TPV, humanTm, gunPitch, humanPhys.phys.currentState.leanPosition, height, gunTm)
  humanPhys.phys.gunOffset = wasOffset
  return gunTm[3]

def calc_anchor_dir(isCrawl : bool; normal : float3; aimTm : float3x4)
  return normalize(isCrawl ?
                   cross(cross(normal, aimTm[0]), normal) :
                   float3(aimTm[0].x, 0., aimTm[0].z))

def calc_human_pos(yaw, anchorPos, offset, normal)
  return anchorPos + quat(normal, yaw) * offset

def get_human_ccd_pos(human_net_phys)
  var ccdTm : float3x4
  location_toTM(human_net_phys.phys.currentState.location, ccdTm)
  return ccdTm * human_net_phys.phys.ccdPos


let
  BIPOD_DEFAULT_PITCH_MIN    = -35.0
  BIPOD_DEFAULT_PITCH_MAX    =  35.0
  BIPOD_WAIT_BEFORE_VALIDATE =  0.2

let
  BIPOD_MIN_GUN_Y_OFFSET     = -2.0
  BIPOD_MAX_GUN_Y_OFFSET     =  2.0

let
  BIPOD_ANGLE_AIMING_COEF        = 0.9
  BIPOD_MAX_YAW_PER_SECOND       = deg_to_rad(200.0)
  BIPOD_MAX_YAW_PER_SECOND_CRAWL = deg_to_rad(125.0)
  BIPOD_MAX_PITCH_PER_SECOND     = deg_to_rad(200.0)

let
  BIPOD_TRACE_REST_RADIUS   = 0.02
  BIPOD_TRACE_BASE_RADIUS   = 0.03
  BIPOD_TRACE_LEG_RADIUS    = 0.015

let
  BIPOD_TRACE_YAW_OFFSET    = 0.07
  BIPOD_TRACE_BACK_OFFSET   = 0.4

let
  BIPOD_MIN_INIT_RADIUS           = 1.2
  BIPOD_MAX_INIT_RADIUS           = 1.8
  BIPOD_MIN_ROTATE_RADIUS         = 0.75
  BIPOD_MAX_ROTATE_RADIUS         = 1.3
  BIPOD_MIN_ROTATE_RADIUS_CRAWL   = 1.0
  BIPOD_MAX_ROTATE_RADIUS_CRAWL   = 1.6

let private
  BIPOD_TRACE_RADIUS        = 0.01
  BIPOD_TRACE_RADIUS_DOWN   = float3(0.0, -BIPOD_TRACE_RADIUS, 0.0)
  BIPOD_TRACE_BASE_UP       = float3(0.0, 0.01 + BIPOD_TRACE_BASE_RADIUS - BIPOD_TRACE_RADIUS, 0.0)
  BIPOD_TRACE_REST_UP       = float3(0.0, 0.01 + BIPOD_TRACE_REST_RADIUS - BIPOD_TRACE_RADIUS + 0.05, 0.0)
  BIPOD_TRACE_DOWN_DIST     = 1.0
  BIPOD_TRACE_DOWN_OFFSET   = float3(0.0, -BIPOD_TRACE_DOWN_DIST, 0.0)
  BIPOD_SPHERE_CAST_MASK    = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC) | int(PhysLayer.EPL_DEBRIS))
  BIPOD_CRAWL_OFFSET_DOWN   = 0.1
  BIPOD_PLACE_GUN_BACKDIST  = 0.3

let private
  BIPOD_MAX_SLOPE_RADIANS   = deg_to_rad(7.0)
  BIPOD_MIN_NORMAL_Y_BIPOD  = 0.939692 
  BIPOD_MIN_NORMAL_Y_REST   = 0.5 
  BIPOD_REST_HEIGHT         = BIPOD_TRACE_RADIUS * 2.0
  BIPOD_REST_HEIGHT_CRAWL   = 0.2
  BIPOD_REST_HIGHER_CRAWL   = 0.01
  BIPOD_FLAT_WEAPON_YOFS    = 0.07
  BIPOD_PITCH_DOWN_HT       = 0.05
  BIPOD_CRAWL_MORE_HT       = 0.1
  BIPOD_STAND_HIGHER        = float3(0.0,  0.05, 0.0)
  BIPOD_CRAWL_LOWER         = float3(0.0, -0.17, 0.0)
  BIPOD_BARREL_ANGLE        = deg_to_rad(3.0)
  BIPOD_BARREL_ANGLE_CRAWL  = deg_to_rad(30.0)
  BIPOD_MAX_STEPS_BACK      = 3
  BIPOD_MAX_STEPS_FORWARD   = 7
  BIPOD_STEP_MAX_DH         = 0.15

let private
  BIPOD_DEFAULT_YAWLIMIT_BIPOD_DEGREES = 180.0 * 0.9
  BIPOD_DEFAULT_YAWLIMIT_REST_DEGREES  = 180.0 * 0.7
  BIPOD_DEFAULT_YAWLIMIT_CRAWL_DEGREES = 180.0 * 0.3

let private
  BIPOD_OFF_DIST_EPSILON    = 0.20
  BIPOD_OFF_DIST_EPSILON_SQ = square(BIPOD_OFF_DIST_EPSILON)
  BIPOD_OFF_DIR_EPSILON     = 0.30
  BIPOD_OFF_DIR_EPSILON_SQ  = square(BIPOD_OFF_DIR_EPSILON)

let private
  BIPOD_FUNC_INIT         = 0
  BIPOD_FUNC_TRY_POINTS   = 1
  BIPOD_FUNC_TRY_HEIGHTS  = 2
  BIPOD_FUNC_STEP_FORWARD = 3
  BIPOD_FUNC_STEP_BACK    = 4

let private
  BIPOD_PRESTEP      = -1000
  BIPOD_RESULT_NONE  = 0
  BIPOD_RESULT_REST  = 1
  BIPOD_RESULT_BIPOD = 2


def private check_bipod_context(gun_eid : EntityId; at_pos : float3; aim_dir : float3; is_crawl : bool;
                                for_gun_eid : EntityId; for_pos : float3; for_dir : float3; for_crawl : bool)
  if gun_eid != for_gun_eid
    return false
  if distance_sq(at_pos, for_pos) > BIPOD_OFF_DIST_EPSILON_SQ
    return false
  if distance_sq(aim_dir, for_dir) > BIPOD_OFF_DIR_EPSILON_SQ
    return false
  if is_crawl != for_crawl
    return false
  return true

def private check_place_gun_barrel(tm : float3x4; barrel_offset : float3; barrel_radius : float; trace_handle : TraceMeshFaces?) : bool
  let traceFrom = tm[3] - tm[0] * BIPOD_PLACE_GUN_BACKDIST
  let traceTo = tm * barrel_offset
  var queryOut = ShapeQueryOutput()
  return !sphere_cast_ex(traceFrom, traceTo, barrel_radius, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)

def private check_place_gun_barrel_diff(tm : float3x4; diff : float3; barrel_offset : float3; barrel_radius : float; trace_handle : TraceMeshFaces?) : bool
  let traceFrom = tm[3] - tm[0] * BIPOD_PLACE_GUN_BACKDIST + diff
  let traceTo = tm * barrel_offset + diff
  var queryOut = ShapeQueryOutput()
  if sphere_cast_ex(traceFrom, traceTo, barrel_radius, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
    return false
  var d = traceTo - traceFrom
  let t = length(d)
  d /= t
  if rayhit_normalized(traceFrom, d, t, ETF_DEFAULT, -1)
    return false
  return true


def update_bipod_placing(bipod_eid : EntityId; full_check : bool; gun_eid : EntityId; at_pos : float3; aim_dir : float3; is_crawl : bool;
                         gun_pos_stand : float3; gun_pos_crouch : float3; gun_pos_crawl : float3; human_height : float; human_radius : float;
                         var placeable : bool&; var placeCrawl : bool&;
                         var placePos : float3&; var placeHeight : float&; var placeOffset : float3&;
                         var placeNormal : float3&; var placeYawLimit : float&; var placeRecoilMult : float&;
                         force_bipod_offset : float3; force_bipod_recoil_mult : float; mount_points : Array; barrel_offset : float3; barrel_radius : float;
                         trace_handle : TraceMeshFaces?)
  query(bipod_eid) <| $ [es] (bipod__solveMaxIterationsPerCall : int = 5;
                              var bipod__solveStep : int&;
                              var bipod__solveFunc : int&;
                              var bipod__solveIter : int&;
                              var bipod__solveForPos : float3&;
                              var bipod__solveForDir : float3&;
                              var bipod__solveForCrawl : bool&;
                              var bipod__solveForGun : EntityId&;
                              var bipod__solveGunPosHigh : float3&;
                              var bipod__solveGunPosLow : float3&;
                              var bipod__solveHumanRadius : float&;
                              var bipod__solveHumanHeight : float&;
                              var bipod__solveLastPos : float3&;
                              var bipod__solveTraceTm : float3x4&;
                              var bipod__solveTracePt : float3&;
                              var bipod__solveBestType : int&;
                              var bipod__solveBestScore : int&;
                              var bipod__solveBestPos : float3&;
                              var bipod__solveBestHeight : float&;
                              var bipod__solveBestOffset : float3&;
                              var bipod__solveBestNormal : float3&;
                              var bipod__solveBestRecoilMult : float&)
    if full_check
      placeable = false
      bipod__solveFunc = BIPOD_FUNC_INIT

    let maxIterations = full_check ? 1000 : bipod__solveMaxIterationsPerCall

    
    
    
    for _i in range(maxIterations)

      
      
      if bipod__solveFunc != BIPOD_FUNC_INIT
        if !check_bipod_context(gun_eid, at_pos, aim_dir, is_crawl,
                                bipod__solveForGun, bipod__solveForPos, bipod__solveForDir, bipod__solveForCrawl)
          placeable = false
          bipod__solveFunc = BIPOD_FUNC_INIT

      
      
      var finish = true

      
      
      
      if bipod__solveFunc == BIPOD_FUNC_INIT
        var gunTm : float3x4
        if !get_gun_tm(gun_eid, gunTm)
          placeable = false
          return

        finish = false

        bipod__solveForPos      = at_pos
        bipod__solveForDir      = aim_dir
        bipod__solveForCrawl    = is_crawl
        bipod__solveForGun      = gun_eid
        bipod__solveGunPosHigh  = is_crawl ? gun_pos_crawl : (gun_pos_stand + BIPOD_STAND_HIGHER)
        bipod__solveGunPosLow   = is_crawl ? (gun_pos_crawl + BIPOD_CRAWL_LOWER) : gun_pos_crouch
        bipod__solveHumanRadius = human_radius
        bipod__solveHumanHeight = is_crawl ? human_radius : human_height
        bipod__solveLastPos     = at_pos
        bipod__solveBestType    = BIPOD_RESULT_NONE
        bipod__solveBestScore   = 0

        
        
        
        
        
        
        bipod__solveStep = 0
        bipod__solveFunc = BIPOD_FUNC_TRY_HEIGHTS    
        bipod__solveIter = 0

      
      
      
      elif bipod__solveFunc == BIPOD_FUNC_TRY_POINTS
        let idx = bipod__solveIter >> 4  
        if idx < length(mount_points)
          let obj = mount_points[idx] as Object
          let typ = obj?["type"] ?? ""
          var nxt = false

          
          
          if typ == "bipod"
            var ofs = obj?.offset ?? float3()
            if idx == 0 && force_bipod_offset.x != 0.0
              if !(obj?.forceOffset ?? false)
                ofs = force_bipod_offset
            let trc = bipod__solveIter & 15  
            if trc == 0
              let pt1 = bipod__solveTraceTm * float3(ofs.x, 0.0, ofs.z)  
              let pt2 = bipod__solveTraceTm * ofs                        
              var queryOut = ShapeQueryOutput()
              if abs(ofs.y) < 0.0001 || !sphere_cast_ex(pt1, pt2, BIPOD_TRACE_BASE_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                nxt = true 
            else
              let ang = deg_to_rad(obj?.angle ?? 0.0)    
              let len = obj?.length ?? 0.0               
              let dy = cos(ang) * len
              let dz = sin(ang) * len
              let leg = ofs + float3(0.0, -dy, (trc <= 2) ? dz : -dz)  
              if trc == 1
                let pt1 = bipod__solveTraceTm * ofs      
                let pt2 = bipod__solveTraceTm * leg      
                var queryOut = ShapeQueryOutput()
                if !sphere_cast_ex(pt1, pt2, BIPOD_TRACE_LEG_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                  nxt = true 
              elif trc == 2
                let pt1 = bipod__solveTraceTm * leg      
                let pt2 = pt1 + BIPOD_TRACE_DOWN_OFFSET  
                var queryOut = ShapeQueryOutput()
                if sphere_cast_ex(pt1, pt2, BIPOD_TRACE_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                  
                  if abs(queryOut.norm.y) >= BIPOD_MIN_NORMAL_Y_BIPOD
                    bipod__solveTracePt = pt1 + queryOut.t * BIPOD_TRACE_DOWN_OFFSET
                    nxt = true 
              elif trc == 3
                let pt1 = bipod__solveTraceTm * ofs      
                let pt2 = bipod__solveTraceTm * leg      
                var queryOut = ShapeQueryOutput()
                if !sphere_cast_ex(pt1, pt2, BIPOD_TRACE_LEG_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                  nxt = true 
              elif trc == 4
                let pt1 = bipod__solveTraceTm * leg      
                let pt2 = pt1 + BIPOD_TRACE_DOWN_OFFSET  
                var queryOut = ShapeQueryOutput()
                if sphere_cast_ex(pt1, pt2, BIPOD_TRACE_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                  
                  if abs(queryOut.norm.y) >= BIPOD_MIN_NORMAL_Y_BIPOD
                    let secondPt = pt1 + queryOut.t * BIPOD_TRACE_DOWN_OFFSET  
                    let delta = bipod__solveTracePt - secondPt                 
                    let rad = atan2(delta.y, length(delta.xz))                 
                    let pt = secondPt + delta * 0.5                            
                    let anchorHt = pt.y - BIPOD_TRACE_RADIUS + dy - (bipod__solveForCrawl ? BIPOD_CRAWL_OFFSET_DOWN : ofs.y)  
                    let needMoreHt = bipod__solveForCrawl ? -BIPOD_CRAWL_MORE_HT : BIPOD_PITCH_DOWN_HT                        
                    if abs(rad) <= BIPOD_MAX_SLOPE_RADIANS && anchorHt >= bipod__solveGunPosLow.y && bipod__solveGunPosHigh.y - needMoreHt >= anchorHt
                      let legL = ofs + float3(0.0, -dy, dz)
                      let pt0 = bipod__solveTraceTm * legL
                      let diff = ((bipod__solveTracePt - pt0) + (secondPt - pt1)) * 0.5 + BIPOD_TRACE_BASE_UP  
                      if bipod__solveForCrawl || check_place_gun_barrel_diff(bipod__solveTraceTm, diff, barrel_offset, barrel_radius, trace_handle)
                        let score = -idx * 100 + (bipod__solveStep >= 0 ? bipod__solveStep * 1000 : 0)
                        if bipod__solveBestType <= BIPOD_RESULT_REST || (bipod__solveBestType == BIPOD_RESULT_BIPOD && score > bipod__solveBestScore)
                          
                          bipod__solveBestType       = BIPOD_RESULT_BIPOD
                          bipod__solveBestScore      = score
                          bipod__solveBestPos        = pt + BIPOD_TRACE_RADIUS_DOWN
                          bipod__solveBestHeight     = dy
                          bipod__solveBestOffset     = ofs
                          bipod__solveBestNormal     = queryOut.norm
                          bipod__solveBestNormal.y   = abs(bipod__solveBestNormal.y)
                          bipod__solveBestRecoilMult = (idx == 0 && force_bipod_recoil_mult >= 0.0) ? force_bipod_recoil_mult : (obj?.recoil ?? 0.5)

          
          
          elif typ == "rest"
            let ofs = obj?.offset ?? float3()
            let trc = bipod__solveIter & 15  
            if trc == 0
              let pt1 = bipod__solveTraceTm * float3(ofs.x, 0.0, ofs.z)  
              let pt2 = bipod__solveTraceTm * ofs                        
              var queryOut = ShapeQueryOutput()
              if abs(ofs.y) < 0.0001 || !sphere_cast_ex(pt1, pt2, BIPOD_TRACE_REST_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                nxt = true 
            else
              let pt1 = bipod__solveTraceTm * ofs                        
              let pt2 = pt1 + BIPOD_TRACE_DOWN_OFFSET                    
              var queryOut = ShapeQueryOutput()
              if sphere_cast_ex(pt1, pt2, BIPOD_TRACE_RADIUS, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
                
                if abs(queryOut.norm.y) >= BIPOD_MIN_NORMAL_Y_REST
                  var downHeight = BIPOD_TRACE_DOWN_DIST - BIPOD_TRACE_RADIUS
                  if tracedown_normalized(pt1, downHeight, ETF_DEFAULT)
                    let pt = pt1 - float3(0.0, downHeight, 0.0)      
                    let isFlatWeaponInCrawl = bipod__solveForCrawl && ofs.y > -BIPOD_FLAT_WEAPON_YOFS
                    let anchorHt = pt.y - BIPOD_TRACE_RADIUS + BIPOD_REST_HEIGHT + (isFlatWeaponInCrawl ? BIPOD_REST_HEIGHT_CRAWL : 0.0) - ofs.y  
                    if anchorHt >= bipod__solveGunPosLow.y && bipod__solveGunPosHigh.y >= anchorHt
                      let diff = pt - pt1 + BIPOD_TRACE_REST_UP  
                      if bipod__solveForCrawl || check_place_gun_barrel_diff(bipod__solveTraceTm, diff, barrel_offset, barrel_radius, trace_handle)
                        let score = -idx * 100 + (bipod__solveForCrawl ? int(-ofs.y * 10000.0) : 0) + (bipod__solveStep >= 0 ? bipod__solveStep * 1000 : 0)
                        if bipod__solveBestType == BIPOD_RESULT_NONE || (bipod__solveBestType == BIPOD_RESULT_REST && score > bipod__solveBestScore)
                          
                          bipod__solveBestType       = BIPOD_RESULT_REST
                          bipod__solveBestScore      = score
                          bipod__solveBestPos        = pt + BIPOD_TRACE_RADIUS_DOWN
                          bipod__solveBestHeight     = BIPOD_REST_HEIGHT + (isFlatWeaponInCrawl ? BIPOD_REST_HEIGHT_CRAWL : bipod__solveForCrawl ? BIPOD_REST_HIGHER_CRAWL : 0.0)
                          bipod__solveBestOffset     = ofs
                          bipod__solveBestNormal     = queryOut.norm
                          bipod__solveBestNormal.y   = abs(bipod__solveBestNormal.y)
                          bipod__solveBestRecoilMult = (idx == 0 && force_bipod_recoil_mult >= 0.0) ? force_bipod_recoil_mult : (obj?.recoil ?? 0.5)
                          if isFlatWeaponInCrawl
                            let inHandsRecoilMult = 1.2
                            bipod__solveBestRecoilMult = min(1.0, bipod__solveBestRecoilMult * inHandsRecoilMult)

          
          
          if nxt
            ++bipod__solveIter
          else
            bipod__solveIter = (idx + 1) << 4

        
        
        finish = false

        let idxNext = bipod__solveIter >> 4
        if idxNext >= length(mount_points)
          
          
          
          if bipod__solveBestType < BIPOD_RESULT_BIPOD   
            if bipod__solveStep == BIPOD_PRESTEP
              bipod__solveStep = 0                       
              bipod__solveFunc = BIPOD_FUNC_TRY_HEIGHTS
              bipod__solveIter = 0
            elif !bipod__solveForCrawl && bipod__solveStep >= 0 && bipod__solveStep < BIPOD_MAX_STEPS_FORWARD
              bipod__solveStep += 1
              bipod__solveFunc = BIPOD_FUNC_STEP_FORWARD 
              bipod__solveIter = 0
            elif bipod__solveStep >= BIPOD_MAX_STEPS_FORWARD || (bipod__solveStep == 0 && bipod__solveForCrawl)
              let moved = bipod__solveForPos - bipod__solveLastPos
              bipod__solveLastPos = bipod__solveForPos
              bipod__solveGunPosHigh += moved
              bipod__solveGunPosLow  += moved
              bipod__solveStep = -1
              bipod__solveFunc = BIPOD_FUNC_STEP_BACK    
              bipod__solveIter = 0
            elif bipod__solveStep < 0 && bipod__solveStep > -BIPOD_MAX_STEPS_BACK
              bipod__solveStep -= 1
              bipod__solveFunc = BIPOD_FUNC_STEP_BACK    
              bipod__solveIter = 0
            else
              finish = true                              
          elif !bipod__solveForCrawl && (bipod__solveStep == BIPOD_PRESTEP || (bipod__solveStep <= 0 && bipod__solveStep > -BIPOD_MAX_STEPS_BACK))
            if bipod__solveStep == BIPOD_PRESTEP
              bipod__solveStep = 0                       
            bipod__solveStep -= 1
            bipod__solveFunc = BIPOD_FUNC_STEP_BACK      
            bipod__solveIter = 0
          else
            finish = true                                

      
      
      
      elif bipod__solveFunc == BIPOD_FUNC_TRY_HEIGHTS
        let HT_DIST = 0.10
        let MAX_STEPS = 20
        let dist = distance(bipod__solveGunPosHigh, bipod__solveGunPosLow)
        let numSteps = clamp(int(floor(dist / HT_DIST)) + 1, 1, MAX_STEPS)

        
        
        finish = false

        if bipod__solveIter <= numSteps
          let ratio = float(bipod__solveIter) / float(numSteps)
          let angle = bipod__solveForCrawl ? BIPOD_BARREL_ANGLE_CRAWL : BIPOD_BARREL_ANGLE
          let kcos = cos(angle)
          let ksin = sin(angle)
          
          
          
          bipod__solveTraceTm[0] = float3(bipod__solveForDir.x * kcos, ksin,  bipod__solveForDir.z * kcos)
          bipod__solveTraceTm[1] = float3(-bipod__solveForDir.x * ksin, kcos, -bipod__solveForDir.z * ksin)
          bipod__solveTraceTm[2] = float3(-bipod__solveForDir.z, 0.0, bipod__solveForDir.x)
          bipod__solveTraceTm[3] = lerp(bipod__solveGunPosHigh, bipod__solveGunPosLow, float3(ratio))
          if check_place_gun_barrel(bipod__solveTraceTm, barrel_offset, barrel_radius, trace_handle)
            bipod__solveFunc = BIPOD_FUNC_TRY_POINTS  
            bipod__solveIter = 0
          else
            ++bipod__solveIter                        
        elif bipod__solveStep <= 0 && bipod__solveStep > -BIPOD_MAX_STEPS_BACK
          bipod__solveStep -= 1
          bipod__solveFunc = BIPOD_FUNC_STEP_BACK     
          bipod__solveIter = 0
        else
          finish = true                               

      
      
      
      elif bipod__solveFunc == BIPOD_FUNC_STEP_FORWARD
        let stepDist = human_radius * 0.1
        if bipod__solveIter == 0
          let pt1 = bipod__solveLastPos + float3(0.0, human_height - human_radius, 0.0)         
          let pt2 = pt1 + float3(bipod__solveForDir.x, 0.0, bipod__solveForDir.z) * stepDist    
          var queryOut = ShapeQueryOutput()
          if !sphere_cast_ex(pt1, pt2, human_radius, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
            finish = false
            bipod__solveIter = 1
            bipod__solveTracePt = pt2                    
          elif queryOut.t > 0.1
            finish = false
            bipod__solveIter = 1
            bipod__solveTracePt = pt1 + (pt2 - pt1) * queryOut.t
            bipod__solveStep = BIPOD_MAX_STEPS_FORWARD   
        elif bipod__solveIter == 1
          let delta = -float3(0.0, human_height - human_radius * 2.0 + BIPOD_STEP_MAX_DH, 0.0)
          let pt1 = bipod__solveTracePt                  
          let pt2 = pt1 + delta                          
          var queryOut = ShapeQueryOutput()
          if sphere_cast_ex(pt1, pt2, human_radius, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
            let pt = pt1 + delta * queryOut.t - float3(0.0, human_radius, 0.0)
            if pt.y < bipod__solveLastPos.y + BIPOD_STEP_MAX_DH
              finish = false
              let moved = pt - bipod__solveLastPos
              bipod__solveLastPos = pt
              bipod__solveGunPosHigh += moved
              bipod__solveGunPosLow  += moved
              bipod__solveFunc = BIPOD_FUNC_TRY_HEIGHTS  
              bipod__solveIter = 0

        if finish && !bipod__solveForCrawl && bipod__solveBestType < BIPOD_RESULT_BIPOD
          finish = false
          let moved = bipod__solveForPos - bipod__solveLastPos
          bipod__solveLastPos = bipod__solveForPos
          bipod__solveGunPosHigh += moved
          bipod__solveGunPosLow  += moved
          bipod__solveStep = -1
          bipod__solveFunc = BIPOD_FUNC_STEP_BACK  
          bipod__solveIter = 0

      
      
      
      elif bipod__solveFunc == BIPOD_FUNC_STEP_BACK
        let stepDist = human_radius * 0.5
        if bipod__solveIter == 0
          let pt1 = bipod__solveLastPos + float3(0.0, human_height - human_radius, 0.0)        
          let pt2 = pt1 + float3(bipod__solveForDir.x, 0.0, bipod__solveForDir.z) * -stepDist  
          var queryOut = ShapeQueryOutput()
          if !sphere_cast_ex(pt1, pt2, human_radius, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
            finish = false
            bipod__solveIter = 1
            bipod__solveTracePt = pt2                    
          elif queryOut.t > 0.1
            finish = false
            bipod__solveIter = 1
            bipod__solveTracePt = pt1 + (pt2 - pt1) * queryOut.t
            bipod__solveStep = -BIPOD_MAX_STEPS_BACK     
        elif bipod__solveIter == 1
          let delta = -float3(0.0, human_height - human_radius * 2.0 + BIPOD_STEP_MAX_DH, 0.0)
          let pt1 = bipod__solveTracePt                  
          let pt2 = pt1 + delta                          
          var queryOut = ShapeQueryOutput()
          if sphere_cast_ex(pt1, pt2, human_radius, queryOut, -1, trace_handle, BIPOD_SPHERE_CAST_MASK)
            let pt = pt1 + delta * queryOut.t - float3(0.0, human_radius, 0.0)
            if pt.y < bipod__solveLastPos.y + BIPOD_STEP_MAX_DH
              finish = false
              let moved = pt - bipod__solveLastPos
              bipod__solveLastPos = pt
              bipod__solveGunPosHigh += moved
              bipod__solveGunPosLow  += moved
              bipod__solveFunc = BIPOD_FUNC_TRY_HEIGHTS  
              bipod__solveIter = 0

      
      

      
      
      if finish
        bipod__solveFunc = BIPOD_FUNC_INIT
        placeable = false
        if bipod__solveBestType > BIPOD_RESULT_NONE
          placeable       = true
          placeCrawl      = bipod__solveForCrawl
          placePos        = bipod__solveBestPos
          placeHeight     = bipod__solveBestHeight
          placeOffset     = bipod__solveBestOffset
          placeNormal     = bipod__solveBestNormal
          placeYawLimit   = 0.0
          placeRecoilMult = bipod__solveBestRecoilMult

          query(gun_eid) <| $ [es] (gun__mountBipodYawLimit : float = BIPOD_DEFAULT_YAWLIMIT_BIPOD_DEGREES;
                                    gun__mountRestYawLimit : float = BIPOD_DEFAULT_YAWLIMIT_REST_DEGREES;
                                    gun__mountCrawlYawLimit : float = BIPOD_DEFAULT_YAWLIMIT_CRAWL_DEGREES)
            if placeCrawl
              placeYawLimit = deg_to_rad(gun__mountCrawlYawLimit)
            elif bipod__solveBestType == BIPOD_RESULT_BIPOD
              placeYawLimit = deg_to_rad(gun__mountBipodYawLimit)
            elif bipod__solveBestType == BIPOD_RESULT_REST
              placeYawLimit = deg_to_rad(gun__mountRestYawLimit)

        if full_check
          return

    
    
    


def solve_bipod_placing(eid : EntityId; full_check : bool)
  query(eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                        human_input__aimAngle : float2;
                        human_input__standState : int;
                        var human_net_phys : HumanActor;
                        human_net_phys__isSwimming : bool;
                        human_net_phys__isOnGround : bool;
                        human_net_phys__isUnderwater : bool;
                        isDowned, isAlive : bool;
                        human_attached_gun__attachedGunEid : EntityId;
                        var bipod__placeable : bool&;
                        var bipod__placeCrawl : bool&;
                        var bipod__placePos : float3&;
                        var bipod__placeHeight : float&;
                        var bipod__placeOffset : float3&;
                        var bipod__placeNormal : float3&;
                        var bipod__placeYawLimit : float&;
                        var bipod__placeRecoilMult : float&;
                        human_cam__calculatedOffset : DPoint3 const?;
                        human_cam__offsetMult : float = 1.0)
    let isInAir = (uint(human_net_phys.phys.currentState.isInAirHistory) & 1u) != 0u
    let isCrawl = human_input__standState == int(HumanPhysControlType.HCT_CRAWL)

    let isHumanPhysStateValid = (!isDowned &&
                                  isAlive &&
                                 !isInAir &&
                                 !human_attached_gun__attachedGunEid &&
                                 !human_net_phys__isSwimming &&
                                 !human_net_phys__isUnderwater &&
                                  human_net_phys__isOnGround &&
                                  !(isCrawl && human_net_phys.phys.previousState.height > -1.0))
    if !isHumanPhysStateValid
      bipod__placeable = false
      return

    query(human_weap__currentGunEid) <| $ [es] (gun__bipodOffset : float3;
                                                gun__bipodRecoilMult : float;
                                                @shared_comp gun__mountPoints : Array;
                                                gun__barrelTipOffset : float3;
                                                gun__barrelRadius : float)
      var humanTm : float3x4
      location_toTM(human_net_phys.phys.currentState.location, humanTm)

      let posDelta = (isCrawl ? 0.15 : 0.0) * humanTm[2]
      humanTm[3] += posDelta

      let curPos  = humanTm[3]
      let aimDir  = angles_to_dir(human_input__aimAngle)

      let additionalOffset = x0z(human_cam__calculatedOffset != null ? float3(*human_cam__calculatedOffset * human_cam__offsetMult) : float3())
      let gunPosStand = calc_tpv_gun_pos_for_height(human_net_phys, humanTm, 0.0,  1.0) + additionalOffset
      let gunPosCrouch = calc_tpv_gun_pos_for_height(human_net_phys, humanTm, 0.0,  -0.5) + additionalOffset
      let gunPosCrawl = calc_tpv_gun_pos_for_height(human_net_phys, humanTm, 0.0, -1.0) + additionalOffset

      assume humanTraceHandle = human_net_phys.phys |> human_phys_getTraceHandle()

      let humanRadius = human_net_phys.phys.walkRad
      let humanHeight = !isCrawl ? human_net_phys.phys.standingHeight : (humanRadius * 2.01)

      update_bipod_placing(eid, full_check, human_weap__currentGunEid, curPos, aimDir, isCrawl,
                           gunPosStand, gunPosCrouch, gunPosCrawl, humanHeight, humanRadius,
                           bipod__placeable, bipod__placeCrawl,
                           bipod__placePos, bipod__placeHeight, bipod__placeOffset,
                           bipod__placeNormal, bipod__placeYawLimit, bipod__placeRecoilMult,
                           gun__bipodOffset, gun__bipodRecoilMult, gun__mountPoints, gun__barrelTipOffset, gun__barrelRadius,
                           humanTraceHandle)
