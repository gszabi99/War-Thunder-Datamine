require ecs
require DagorSystem
require DagorConsole
require Unit
require DagorDataBlock
require WTHangar
require HeroManager
require Music
require app
require %dasGameLibs.math.base
require MPlayer
require %game.utils.utils_common
require %game.events
require strings


enum GameState
  HANGAR
  MISSION
  MISSION_MENU
  FORCED
  WIN
  LOOSE
  UNDEFINED


enum BattleState
  CALM
  ACTION
  TOP_TIER

let NUM_COUNTRIES = 21
let NUM_OPERATOR_COUNTRIES = 3

let country_names = fixed_array<string>("australia",
                                  "britain",
                                  "germany",
                                  "italy",
                                  "japan",
                                  "usa",
                                  "ussr",
                                  "china",
                                  "france",
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "", 
                                  "sweden",
                                  "israel")

let operator_country_names = fixed_array<string>("south_africa",
                                  "hungary",
                                  "finland")

[es(tag=sound, on_event=(EventEntityCreated, EventComponentsAppear))]
def music_init_es(evt : Event;
                  var music__forced : bool&;
                  var music__lockedHangar : bool&;
                  var music__curBattleState : int&;
                  var music__battleRadiusAirSq : float&;
                  var music__battleRadiusGroundSq : float&;
                  var music__battleEnemiesThreshold : int&;
                  var music__cooldownBattle : float&;
                  var music__useHangarMusicForUnitType : bool&;
                  var music__cooldownCalm : float&)
  music__forced = false
  music__lockedHangar = false
  music__curBattleState = int(BattleState.CALM)
  init_delayed_forced_track()
  using() <| $(var blk : DataBlock)
    if datablock_load(blk, "config/sound_studio.blk")
      let musicBlk = blk |> datablock_get_block_by_name("music")
      music__battleRadiusAirSq = square(musicBlk |> datablock_getReal("battleRadius", 3000.))
      music__battleRadiusGroundSq = square(musicBlk |> datablock_getReal("battleRadiusGround", 500.))
      music__battleEnemiesThreshold = musicBlk |> datablock_getInt("battleEnemiesThreshold", 3)
      music__cooldownCalm = musicBlk |> datablock_getReal("cooldown_calm", 300.)
      music__cooldownBattle = musicBlk |> datablock_getReal("cooldown_battle", 180.)
      music__useHangarMusicForUnitType = musicBlk |> datablock_getBool("use_hangar_music_for_type", false)
  print("[MUSIC] es inited")


def get_game_state(forced : bool) : GameState
  if is_in_hangar()
    return forced ? GameState.FORCED : GameState.HANGAR
  else
    let app = get_app()
    if app != null
      if app.isMissionRunning
        let localPlayer = player_get_local()
        if forced
          return GameState.FORCED
        elif localPlayer != null && (!localPlayer.isInFlight || *app |> checkInFlightMenu(false))
          return GameState.MISSION_MENU
        else
          return GameState.MISSION
      elif app.isMissionSuccessful
        return GameState.WIN
      elif app.isMissionFailed
        return GameState.LOOSE
  return GameState.UNDEFINED


def get_battle_state(radius_air_sq : float;
                     radius_ground_sq : float;
                     max_num_enemies : int) : BattleState
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return BattleState.CALM
  let heroPos = hero.pos

  var numEnemies = 0
  ecs::query() <| $ [es] (unit__ref : UnitRef;
                          unitType : int)
    let unit = unit__ref.unit
    if unit.army != hero.army && !unit.isDelayed
      let unitPos = unit.pos
      let radiusSq = (unitType == int(UnitType.UT_Airplane)) ? radius_air_sq : radius_ground_sq
      if (length_sq(unitPos - heroPos) < radiusSq)
        numEnemies++

  var maxRage = false
  ecs::query() <| $ [es(REQUIRE=controlledHero)] (loot_carrier__rage : int)
    if loot_carrier__rage >= 5
      maxRage = true

  if (numEnemies > max_num_enemies || maxRage)
    return BattleState.ACTION
  return BattleState.CALM


def delay_battle_state(new_state : BattleState;
                       cur_state : int;
                       var timer_battle : float&;
                       cooldown : float) : bool
  if cur_state != int(new_state)
    if timer_battle > cooldown
      return true
  else
    timer_battle = 0.
  return false


def rank_is_top_tier(unit_rank : int;
                     unit_type : int) : bool
  let topTierThresholdAir = 5
  let topTierThresholdTank = 6
  if unit_type == int(UnitType.UT_HeavyVehicle)
    return unit_rank >= topTierThresholdTank
  elif unit_type == int(UnitType.UT_Airplane)
    return unit_rank >= topTierThresholdAir
  else
    return false


def unit_rank_or_type_changed(unit_rank : int;
                              unit_type : int;
                              cur_unit_rank : int;
                              cur_unit_type : int) : bool
  let rankChanged = (rank_is_top_tier(cur_unit_rank, cur_unit_type) != rank_is_top_tier(unit_rank, unit_type))
  let typeChanged = (unit_type == int(UnitType.UT_HeavyVehicle) || unit_type == int(UnitType.UT_Airplane)) ? (unit_type != cur_unit_type) : false
  return rankChanged || typeChanged


def get_current_country_id(default_value : int) : int
  let hero = get_controlled_hero()
  if hero == null || hero.isDelayed
    return default_value
  return hero.unitCountryId

def get_operator_country_id(country : string) : int
  if country != ""
    var operatorCountry = country
    operatorCountry = operatorCountry |> replace("country_", "")
    operatorCountry = operatorCountry |> replace("_modern", "")
    for i in range(0, length(operator_country_names))
      if operatorCountry == operator_country_names[i]
        return i
  return -1

def update_battle_state(battle_radius_air_sq : float;
                        battle_radius_ground_sq : float;
                        battle_enemies_threshold : int;
                        var cur_battle_state : int&;
                        cooldown_battle : float;
                        cooldown_calm : float;
                        var timer_battle : float&;
                        dt : float)
  let battleState = get_battle_state(battle_radius_air_sq, battle_radius_ground_sq, battle_enemies_threshold)
  let cooldown = (battleState == BattleState.ACTION) ? cooldown_battle : cooldown_calm
  timer_battle += dt
  if delay_battle_state(battleState, cur_battle_state, timer_battle, cooldown) || cur_battle_state >= int(BattleState.TOP_TIER)
    cur_battle_state = int(battleState)


def get_music_state_from_battle_state(unit : Unit?;
                                      battle_state : int) : GameMusicState
  if battle_state == int(BattleState.CALM)
    if unit.isShip
      return GameMusicState.MUSIC_STATE_CALM_SHIPS
    elif unit.isTank
      return GameMusicState.MUSIC_STATE_CALM_TANKS
    else
      return GameMusicState.MUSIC_STATE_CALM
  elif battle_state == int(BattleState.ACTION)
    if unit.isShip
      return GameMusicState.MUSIC_STATE_ACTION_SHIPS
    elif unit.isTank
      return GameMusicState.MUSIC_STATE_ACTION_TANKS
    else
      return GameMusicState.MUSIC_STATE_ACTION
  elif battle_state == int(BattleState.TOP_TIER)
    if unit.isTank
      return GameMusicState.MUSIC_STATE_TOP_TIER_TANK
    else
      return GameMusicState.MUSIC_STATE_TOP_TIER_AIR
  return GameMusicState.MUSIC_STATE_CALM


def make_hangar_operator_event_name(id : int) : string
  if id < 0 || id >= NUM_OPERATOR_COUNTRIES
    return ""
  return operator_country_names[id] + "_main_theme"

def make_hangar_event_name(id : int) : string
  if id < 0 || id >= NUM_COUNTRIES
    return ""
  return country_names[id] + "_main_theme"

def get_hangar_event_name_by_hero_type(hero_type : int) : string
  if hero_type == int(UnitType.UT_Ship) || hero_type == int(UnitType.UT_Submarine)
    return "menu"
  elif hero_type == int(UnitType.UT_HeavyVehicle)
    return "menu_ground"
  else
    return "menu_air"

def make_win_loose_event_name(id : int;
                              win : bool) : string
  if id < 0 || id >= NUM_COUNTRIES
    return ""
  let theme = win ? "_victory_theme" : "_defeat_theme"
  return country_names[id] + theme

def make_win_loose_operator_event_name(id : int;
                                       win : bool) : string
  if id < 0 || id >= NUM_OPERATOR_COUNTRIES
    return ""
  let theme = win ? "_victory_theme" : "_defeat_theme"
  return operator_country_names[id] + theme

def calc_win_loose_track_name(is_win : bool) : string
  let hero = get_controlled_hero()
  let operatorCountry = (hero != null && !hero.isDelayed) ? hero.getOperatorCountry : ""
  let heroOperatorCountryId = get_operator_country_id(operatorCountry)
  if heroOperatorCountryId >= 0
    return make_win_loose_operator_event_name(heroOperatorCountryId, is_win)
  let heroCountryId = (hero != null && !hero.isDelayed) ? hero.unitCountryId : -1
  return make_win_loose_event_name(heroCountryId, is_win)

[es(tag=sound, after=music_es)]
def music_update_special_params_es(info : ParallelUpdateFrameDelayed;
                                   var music__intencity : float&;
                                   music__intencityToMax : float)
  if !has_special_params()
    return
  music__intencity = min(music__intencity + (1. / music__intencityToMax) * info.dt, 1.01)

  var isDead = 0.
  let hero = get_controlled_hero()
  if hero != null
    isDead = !hero.isAlive ? 1. : 0.
  set_special_params(music__intencity, isDead)

[es(on_event=CmdHeroRespawn)]
def music_respawn_handler_es(evt : Event;
                             var music__intencity : float&)
  music__intencity = 0.

[es(tag=sound)]
def music_es(info : ParallelUpdateFrameDelayed;
             music__battleRadiusAirSq : float;
             music__battleRadiusGroundSq : float;
             music__battleEnemiesThreshold : int;
             music__forced : bool;
             var music__curBattleState : int&;
             music__cooldownBattle : float;
             music__cooldownCalm : float;
             var music__timerBattle : float&;
             music__forcedEvtName : string;
             var music__curHangarCountry_id : int&;
             var music__curForcedEvtName : das_string&;
             var music__lockedHangar : bool&;
             music__useHangarMusicForUnitType : bool;
             music__operatorCountryId : int;
             var music__curUnitType : int&)
  let curMusicState = get_music_state()
  let winOrLoosePlaying = ((curMusicState == int(GameMusicState.MUSIC_STATE_WIN) ||
                            curMusicState == int(GameMusicState.MUSIC_STATE_LOOSE)) &&
                            is_track_playing())

  let gameState = get_game_state(music__forced && !winOrLoosePlaying)
  var musicState = GameMusicState.MUSIC_STATE_CALM
  var hangarCountryId = -1
  var hangarTypeChanged = false
  if gameState == GameState.HANGAR
    hangarCountryId = music__operatorCountryId >= 0 ? NUM_COUNTRIES : get_current_country_id(music__curHangarCountry_id)
    musicState = GameMusicState.MUSIC_STATE_HANGAR
    ecs::query() <| $ [es(REQUIRE=controlledHero)] (unitType : int)
      if music__curUnitType != unitType
        hangarTypeChanged = true
        music__curUnitType = unitType
  elif gameState == GameState.MISSION
    var heroRank = -1
    var heroUnitType = -1
    var heroExist = false
    ecs::query() <| $ [es(REQUIRE=controlledHero)] (var unit__ref : UnitRef; unitType : int; loot_carrier__capacity : int const?)
      heroUnitType = unitType
      var hero = unit__ref.unit
      if !hero.isDelayed && hero.props != null && !hero.isSupportPlane
        heroExist = true
        heroRank = hero.props.unitRank
        let app = get_app()
        if loot_carrier__capacity == null && rank_is_top_tier(heroRank, heroUnitType) && app.isMultiplayerGame
          music__curBattleState = int(BattleState.TOP_TIER)
        else
          update_battle_state(music__battleRadiusAirSq, music__battleRadiusGroundSq, music__battleEnemiesThreshold, music__curBattleState, music__cooldownBattle, music__cooldownCalm, music__timerBattle, info.dt)
        music__curUnitType = heroUnitType
        if has_special_params()
          music__curBattleState = int(BattleState.CALM)  
        musicState = get_music_state_from_battle_state(hero, music__curBattleState)
    if !heroExist
      return
  elif gameState == GameState.FORCED
    musicState = GameMusicState.MUSIC_STATE_FORCED
  elif gameState == GameState.WIN
    musicState = GameMusicState.MUSIC_STATE_WIN
  elif gameState == GameState.LOOSE
    musicState = GameMusicState.MUSIC_STATE_LOOSE
  elif gameState == GameState.MISSION_MENU
    return

  let lockedHangar = music__lockedHangar && is_track_playing()
  let hangarCountryChanged = hangarCountryId >= 0 && music__curHangarCountry_id != hangarCountryId
  let hangarTrackEnded = curMusicState == int(GameMusicState.MUSIC_STATE_HANGAR) && !is_track_playing()

  if musicState == GameMusicState.MUSIC_STATE_HANGAR
    if !lockedHangar && !winOrLoosePlaying
      if music__useHangarMusicForUnitType
        if hangarTypeChanged
          let trackName = get_hangar_event_name_by_hero_type(music__curUnitType)
          overwrite_and_set_music_state(int(musicState), trackName)
      elif hangarCountryChanged
        overwrite_and_set_music_state(int(musicState), music__operatorCountryId >= 0 ? make_hangar_operator_event_name(music__operatorCountryId) : make_hangar_event_name(hangarCountryId))
      elif hangarTrackEnded
        overwrite_and_set_music_state(int(musicState), "")
      music__curHangarCountry_id = hangarCountryId
      music__lockedHangar = false
    elif hangarTrackEnded
      overwrite_and_set_music_state(int(musicState), "")
  elif musicState == GameMusicState.MUSIC_STATE_FORCED
    if music__forcedEvtName != ""
      if curMusicState != int(GameMusicState.MUSIC_STATE_FORCED) || string(music__curForcedEvtName) != music__forcedEvtName
        overwrite_and_set_music_state(int(musicState), music__forcedEvtName)
        music__curForcedEvtName := music__forcedEvtName
        music__lockedHangar = false
  elif musicState == GameMusicState.MUSIC_STATE_WIN || musicState == GameMusicState.MUSIC_STATE_LOOSE
    if int(musicState) != curMusicState
      let win_loose_track = calc_win_loose_track_name(musicState == GameMusicState.MUSIC_STATE_WIN)
      overwrite_and_set_music_state(int(musicState), win_loose_track)
  else
    if int(musicState) != curMusicState
      set_mission_music_state(int(musicState))
      music__lockedHangar = false


[es(tag=sound)]
def music_set_forced(evt : CmdForceMusic;
                     var music__forced : bool&;
                     var music__forcedEvtName : das_string&)
  music__forced = true
  music__forcedEvtName := evt.name

[es(tag=sound, on_event = CmdLockHangarMusic)]
def music_lock_hangar_es(evt : Event;
                         var music__lockedHangar : bool&)
  music__lockedHangar = true

[es(tag=sound)]
def music_set_operator_country_es(evt : CmdSetOperatorCountry;
                                  var music__operatorCountryId : int&)
  music__operatorCountryId = get_operator_country_id(string(evt.country))


