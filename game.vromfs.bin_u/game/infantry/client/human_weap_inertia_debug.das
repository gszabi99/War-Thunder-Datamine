options no_aot

require ecs
require DagorConsole
require DagorSystem
require DagorTime
require DagorDataBlock
require DagorFiles


def find_hero_eid() : EntityId
  var heroEid = INVALID_ENTITY_ID
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    heroEid = eid
  return heroEid


[console_cmd(name="aim_inertia.save", hint="Save hero aim inertia. Optional explicit path; default = weap_inertia_HHMMSS.blk")]
def aim_inertia_save_cmd(path : string = "")
  let hero_eid = find_hero_eid()
  if hero_eid == INVALID_ENTITY_ID
    console_print("aim_inertia.save: no hero entity found")
    return

  var filename = path
  if empty(filename)
    let t = get_local_time()
    let pad = ":02d"
    filename = "weap_inertia_{fmt(pad, t.x)}{fmt(pad, t.y)}{fmt(pad, t.z)}.blk"

  var ok = false
  using() <| $(var blk : DataBlock)
    query(hero_eid) <| $ [es] (human_weap__aimInertiaVScaleFrac : float;
                               human_weap__aimInertiaTimeStretchMin : float;
                               human_weap__aimInertiaTimeStretchMax : float;
                               human_weap__aimInertiaTimeStretchBias : float;
                               human_weap__aimInertiaDeltaTime : float;
                               human_weap__aimInertiaMaxMult : float;
                               human_weap__aimInertiaVelocityMax : float;
                               human_weap__aimInertiaCrouchMult : float;
                               human_weap__aimInertiaCrawlMult : float;
                               human_weap__aimInertiaAimingMult : float;
                               human_weap__aimInertiaWeightMin : float;
                               human_weap__aimInertiaWeightMax : float;
                               human_weap__aimInertiaViscosity : float;
                               human_weap__aimInertia_TqScale : float;
                               human_weap__aimInertia_TqLut : FloatList;
                               human_weap__aimInertia_TqLutColumnCount : int;
                               human_weap__aimInertia_TqLutSharpness : float;
                               human_weap__aimInertia_ZetaLut : FloatList;
                               human_weap__aimInertia_ZetaLutColumnCount : int;
                               human_weap__aimInertia_ZetaLutSharpness : float;
                               human_weap__aimInertiaRestPointGainMin : float;
                               human_weap__aimInertiaRestPointGainMax : float;
                               human_weap__aimInertiaRestPointGainBias : float;
                               human_weap__aimInertiaOmegaDrainMin : float;
                               human_weap__aimInertiaOmegaDrainMax : float;
                               human_weap__aimInertiaOmegaDrainBias : float;
                               human_weap__aimInertiaAccumAngleMin : float;
                               human_weap__aimInertiaAccumAngleMax : float;
                               human_weap__aimOmegaViscosity : float)
      blk |> add("human_weap__aimInertiaVScaleFrac", human_weap__aimInertiaVScaleFrac)
      blk |> add("human_weap__aimInertiaTimeStretchMin", human_weap__aimInertiaTimeStretchMin)
      blk |> add("human_weap__aimInertiaTimeStretchMax", human_weap__aimInertiaTimeStretchMax)
      blk |> add("human_weap__aimInertiaTimeStretchBias", human_weap__aimInertiaTimeStretchBias)
      blk |> add("human_weap__aimInertiaDeltaTime", human_weap__aimInertiaDeltaTime)
      blk |> add("human_weap__aimInertiaMaxMult", human_weap__aimInertiaMaxMult)
      blk |> add("human_weap__aimInertiaVelocityMax", human_weap__aimInertiaVelocityMax)
      blk |> add("human_weap__aimInertiaCrouchMult", human_weap__aimInertiaCrouchMult)
      blk |> add("human_weap__aimInertiaCrawlMult", human_weap__aimInertiaCrawlMult)
      blk |> add("human_weap__aimInertiaAimingMult", human_weap__aimInertiaAimingMult)
      blk |> add("human_weap__aimInertiaWeightMin", human_weap__aimInertiaWeightMin)
      blk |> add("human_weap__aimInertiaWeightMax", human_weap__aimInertiaWeightMax)
      blk |> add("human_weap__aimInertiaViscosity", human_weap__aimInertiaViscosity)
      blk |> add("human_weap__aimInertia_TqScale", human_weap__aimInertia_TqScale)
      datablock_add_new_block(blk, "human_weap__aimInertia_TqLut:list<r>") <| $(var tqLutBlk)
        for val in human_weap__aimInertia_TqLut
          add(tqLutBlk, "v", val)
      blk |> add("human_weap__aimInertia_TqLutColumnCount", human_weap__aimInertia_TqLutColumnCount)
      blk |> add("human_weap__aimInertia_TqLutSharpness", human_weap__aimInertia_TqLutSharpness)
      datablock_add_new_block(blk, "human_weap__aimInertia_ZetaLut:list<r>") <| $(var zetaLutBlk)
        for val in human_weap__aimInertia_ZetaLut
          add(zetaLutBlk, "v", val)
      blk |> add("human_weap__aimInertia_ZetaLutColumnCount", human_weap__aimInertia_ZetaLutColumnCount)
      blk |> add("human_weap__aimInertia_ZetaLutSharpness", human_weap__aimInertia_ZetaLutSharpness)
      blk |> add("human_weap__aimInertiaRestPointGainMin", human_weap__aimInertiaRestPointGainMin)
      blk |> add("human_weap__aimInertiaRestPointGainMax", human_weap__aimInertiaRestPointGainMax)
      blk |> add("human_weap__aimInertiaRestPointGainBias", human_weap__aimInertiaRestPointGainBias)
      blk |> add("human_weap__aimInertiaOmegaDrainMin", human_weap__aimInertiaOmegaDrainMin)
      blk |> add("human_weap__aimInertiaOmegaDrainMax", human_weap__aimInertiaOmegaDrainMax)
      blk |> add("human_weap__aimInertiaOmegaDrainBias", human_weap__aimInertiaOmegaDrainBias)
      blk |> add("human_weap__aimInertiaAccumAngleMin", human_weap__aimInertiaAccumAngleMin)
      blk |> add("human_weap__aimInertiaAccumAngleMax", human_weap__aimInertiaAccumAngleMax)
      blk |> add("human_weap__aimOmegaViscosity", human_weap__aimOmegaViscosity)
      ok = true

    if ok
      datablock_save_to_text_file(blk, filename)
      console_print("aim_inertia.save: wrote {filename}")
    else
      console_print("aim_inertia.save: hero has no aim inertia components")


[console_cmd(name="aim_inertia.load", hint="Load aim inertia tuning from a BLK file onto the hero")]
def aim_inertia_load_cmd(path : string)
  let hero_eid = find_hero_eid()
  if hero_eid == INVALID_ENTITY_ID
    console_print("aim_inertia.load: no hero entity found")
    return

  var fileStat : DagorStat
  if df_stat(path, fileStat) < 0
    console_print("aim_inertia.load: file not found: {path}")
    return

  var applied = false
  using() <| $(var blk : DataBlock)
    datablock_load(blk, path, DataBlockReadFlag.ROBUST)
    query(hero_eid) <| $ [es] (var human_weap__aimInertiaVScaleFrac : float&;
                               var human_weap__aimInertiaTimeStretchMin : float&;
                               var human_weap__aimInertiaTimeStretchMax : float&;
                               var human_weap__aimInertiaTimeStretchBias : float&;
                               var human_weap__aimInertiaDeltaTime : float&;
                               var human_weap__aimInertiaMaxMult : float&;
                               var human_weap__aimInertiaVelocityMax : float&;
                               var human_weap__aimInertiaCrouchMult : float&;
                               var human_weap__aimInertiaCrawlMult : float&;
                               var human_weap__aimInertiaAimingMult : float&;
                               var human_weap__aimInertiaWeightMin : float&;
                               var human_weap__aimInertiaWeightMax : float&;
                               var human_weap__aimInertiaViscosity : float&;
                               var human_weap__aimInertia_TqScale : float&;
                               var human_weap__aimInertia_TqLut : FloatList&;
                               var human_weap__aimInertia_TqLutColumnCount : int&;
                               var human_weap__aimInertia_TqLutSharpness : float&;
                               var human_weap__aimInertia_ZetaLut : FloatList&;
                               var human_weap__aimInertia_ZetaLutColumnCount : int&;
                               var human_weap__aimInertia_ZetaLutSharpness : float&;
                               var human_weap__aimInertiaRestPointGainMin : float&;
                               var human_weap__aimInertiaRestPointGainMax : float&;
                               var human_weap__aimInertiaRestPointGainBias : float&;
                               var human_weap__aimInertiaOmegaDrainMin : float&;
                               var human_weap__aimInertiaOmegaDrainMax : float&;
                               var human_weap__aimInertiaOmegaDrainBias : float&;
                               var human_weap__aimInertiaAccumAngleMin : float&;
                               var human_weap__aimInertiaAccumAngleMax : float&;
                               var human_weap__aimOmegaViscosity : float&)
      
      human_weap__aimInertiaVScaleFrac = datablock_getReal(blk, "human_weap__aimInertiaVScaleFrac", human_weap__aimInertiaVScaleFrac)
      human_weap__aimInertiaTimeStretchMin = datablock_getReal(blk, "human_weap__aimInertiaTimeStretchMin", human_weap__aimInertiaTimeStretchMin)
      human_weap__aimInertiaTimeStretchMax = datablock_getReal(blk, "human_weap__aimInertiaTimeStretchMax", human_weap__aimInertiaTimeStretchMax)
      human_weap__aimInertiaTimeStretchBias = datablock_getReal(blk, "human_weap__aimInertiaTimeStretchBias", human_weap__aimInertiaTimeStretchBias)
      human_weap__aimInertiaDeltaTime = datablock_getReal(blk, "human_weap__aimInertiaDeltaTime", human_weap__aimInertiaDeltaTime)
      human_weap__aimInertiaMaxMult = datablock_getReal(blk, "human_weap__aimInertiaMaxMult", human_weap__aimInertiaMaxMult)
      human_weap__aimInertiaVelocityMax = datablock_getReal(blk, "human_weap__aimInertiaVelocityMax", human_weap__aimInertiaVelocityMax)
      human_weap__aimInertiaCrouchMult = datablock_getReal(blk, "human_weap__aimInertiaCrouchMult", human_weap__aimInertiaCrouchMult)
      human_weap__aimInertiaCrawlMult = datablock_getReal(blk, "human_weap__aimInertiaCrawlMult", human_weap__aimInertiaCrawlMult)
      human_weap__aimInertiaAimingMult = datablock_getReal(blk, "human_weap__aimInertiaAimingMult", human_weap__aimInertiaAimingMult)
      human_weap__aimInertiaWeightMin = datablock_getReal(blk, "human_weap__aimInertiaWeightMin", human_weap__aimInertiaWeightMin)
      human_weap__aimInertiaWeightMax = datablock_getReal(blk, "human_weap__aimInertiaWeightMax", human_weap__aimInertiaWeightMax)
      human_weap__aimInertiaViscosity = datablock_getReal(blk, "human_weap__aimInertiaViscosity", human_weap__aimInertiaViscosity)
      human_weap__aimInertia_TqScale = datablock_getReal(blk, "human_weap__aimInertia_TqScale", human_weap__aimInertia_TqScale)
      let tqBlkPtr = datablock_get_block_by_name(blk, "human_weap__aimInertia_TqLut:list<r>")
      if tqBlkPtr != null
        let cnt = int((*tqBlkPtr).paramCount)
        human_weap__aimInertia_TqLut |> resize(cnt)
        for i in range(0, cnt)
          human_weap__aimInertia_TqLut[i] = datablock_getReal(*tqBlkPtr, i)
      human_weap__aimInertia_TqLutColumnCount = datablock_getInt(blk, "human_weap__aimInertia_TqLutColumnCount", human_weap__aimInertia_TqLutColumnCount)
      human_weap__aimInertia_TqLutSharpness = datablock_getReal(blk, "human_weap__aimInertia_TqLutSharpness", human_weap__aimInertia_TqLutSharpness)
      let zetaBlkPtr = datablock_get_block_by_name(blk, "human_weap__aimInertia_ZetaLut:list<r>")
      if zetaBlkPtr != null
        let cnt = int((*zetaBlkPtr).paramCount)
        human_weap__aimInertia_ZetaLut |> resize(cnt)
        for i in range(0, cnt)
          human_weap__aimInertia_ZetaLut[i] = datablock_getReal(*zetaBlkPtr, i)
      human_weap__aimInertia_ZetaLutColumnCount = datablock_getInt(blk, "human_weap__aimInertia_ZetaLutColumnCount", human_weap__aimInertia_ZetaLutColumnCount)
      human_weap__aimInertia_ZetaLutSharpness = datablock_getReal(blk, "human_weap__aimInertia_ZetaLutSharpness", human_weap__aimInertia_ZetaLutSharpness)
      human_weap__aimInertiaRestPointGainMin = datablock_getReal(blk, "human_weap__aimInertiaRestPointGainMin", human_weap__aimInertiaRestPointGainMin)
      human_weap__aimInertiaRestPointGainMax = datablock_getReal(blk, "human_weap__aimInertiaRestPointGainMax", human_weap__aimInertiaRestPointGainMax)
      human_weap__aimInertiaRestPointGainBias = datablock_getReal(blk, "human_weap__aimInertiaRestPointGainBias", human_weap__aimInertiaRestPointGainBias)
      human_weap__aimInertiaOmegaDrainMin = datablock_getReal(blk, "human_weap__aimInertiaOmegaDrainMin", human_weap__aimInertiaOmegaDrainMin)
      human_weap__aimInertiaOmegaDrainMax = datablock_getReal(blk, "human_weap__aimInertiaOmegaDrainMax", human_weap__aimInertiaOmegaDrainMax)
      human_weap__aimInertiaOmegaDrainBias = datablock_getReal(blk, "human_weap__aimInertiaOmegaDrainBias", human_weap__aimInertiaOmegaDrainBias)
      human_weap__aimInertiaAccumAngleMin = datablock_getReal(blk, "human_weap__aimInertiaAccumAngleMin", human_weap__aimInertiaAccumAngleMin)
      human_weap__aimInertiaAccumAngleMax = datablock_getReal(blk, "human_weap__aimInertiaAccumAngleMax", human_weap__aimInertiaAccumAngleMax)
      human_weap__aimOmegaViscosity = datablock_getReal(blk, "human_weap__aimOmegaViscosity", human_weap__aimOmegaViscosity)
      applied = true

  if applied
    console_print("aim_inertia.load: applied {path}")
  else
    console_print("aim_inertia.load: hero has no aim inertia components")
