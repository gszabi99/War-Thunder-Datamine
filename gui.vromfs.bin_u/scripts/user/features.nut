from "%scripts/dagui_natives.nut" import disable_network, local_player_has_feature, has_ray_query

let { Watched } = require("frp")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { platformId } = require("%sqstd/platform.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { get_game_settings_blk } = require("blkGetters")

let is_platform_windows = ["win32", "win64"].contains(platformId)

let defaults = Watched({  //def value when feature not found in game_settings.blk
             // not in this list are false
  SpendGold = true
  CrewSkills = true
  CrewBuyAllSkills = false
  UserLog = true
  Voice = true
  Friends = true
  Squad = true
  SquadWidget = true
  SquadTransferLeadership = false
  SquadSizeChange = false
  SquadInviteIngame = true
  Clans = true
  Battalions = false
  Radio = true
  Events = true
  CreateEventRoom = false
  QueueCustomEventRoom = false
  Invites = true
  Credits = true
  EmbeddedBrowser = is_platform_windows
  EmbeddedBrowserOnlineShop = false

  ChatThreadLang = false
  ChatThreadCategories = false
  ChatThreadCreate = true

  BoatsFirstChoice = false
  ShipsFirstChoice = false

  UsaAircraftsInFirstCountryChoice      = true
  UsaTanksInFirstCountryChoice          = true
  UsaBoatsInFirstCountryChoice          = true
  UsaShipsInFirstCountryChoice          = true
  GermanyAircraftsInFirstCountryChoice  = true
  GermanyTanksInFirstCountryChoice      = true
  GermanyBoatsInFirstCountryChoice      = true
  GermanyShipsInFirstCountryChoice      = true
  UssrAircraftsInFirstCountryChoice     = true
  UssrTanksInFirstCountryChoice         = true
  UssrBoatsInFirstCountryChoice         = true
  UssrShipsInFirstCountryChoice         = true
  BritainAircraftsInFirstCountryChoice  = true
  BritainTanksInFirstCountryChoice      = true
  BritainBoatsInFirstCountryChoice      = true
  BritainShipsInFirstCountryChoice      = true
  JapanAircraftsInFirstCountryChoice    = true
  JapanTanksInFirstCountryChoice        = disable_network()
  JapanBoatsInFirstCountryChoice        = disable_network()
  JapanShipsInFirstCountryChoice        = disable_network()
  ChinaAircraftsInFirstCountryChoice    = true
  ChinaTanksInFirstCountryChoice        = true
  ChinaBoatsInFirstCountryChoice        = disable_network()
  ChinaShipsInFirstCountryChoice        = disable_network()
  ItalyAircraftsInFirstCountryChoice    = true
  ItalyTanksInFirstCountryChoice        = true
  ItalyBoatsInFirstCountryChoice        = disable_network()
  ItalyShipsInFirstCountryChoice        = disable_network()
  FranceAircraftsInFirstCountryChoice   = true
  FranceTanksInFirstCountryChoice       = disable_network()
  FranceBoatsInFirstCountryChoice       = disable_network()
  FranceShipsInFirstCountryChoice       = disable_network()
  DmViewerProtectionAnalysis            = disable_network()
  DmViewerExternalArmorHiding           = true

  Helicopters = disable_network()

  Tribunal = false

  HideDisabledTopMenuActions = false
  ModeSkirmish = true
  ModeBuilder = true
  ModeDynamic = true
  ModeSingleMissions = true
  HistoricalCampaign = true
  Leaderboards = true
  HangarWndHelp = true
  EulaInMenu = true
  WarpointsInMenu = true

  WorldWar = false
  worldWarMaster = false
  worldWarShowTestMaps = false
  WorldWarClansQueue = false
  WorldWarReplay = false
  WorldWarSquadInfo = false
  WorldWarSquadInvite = false
  WorldWarLeaderboards = false
  WorldWarCountryLeaderboard = false

  SpecialShip = false
  Human = false

  GraphicsOptions = true
  Spectator = false
  BuyAllModifications = false
  Packages = true
  DecalsUse = true
  AttachablesUse = disable_network()
  UserSkins = true
  SkinsPreviewOnUnboughtUnits = disable_network()
  SkinAutoSelect = false
  UserMissions = true
  UserMissionsSkirmishLocal = false
  UserMissionsSkirmishByUrl = false
  UserMissionsSkirmishByUrlCreate = false
  ClientReplay = true
  ServerReplay = true
  Encyclopedia = true
  Benchmark = true
  DamageModelViewer = disable_network()
  ShowNextUnlockInfo = false
  extendedReplayInfo = disable_network()
  LiveBroadcast = false
  showAllUnitsRanks = false
  EarlyExitCrewUnlock = false
  UnitTooltipImage = true

  ActivityFeedPs4 = false

  UnlockAllCountries = false

  GameModeSelector = true
  AllModesInRandomBattles = true
  SimulatorDifficulty = true
  SimulatorDifficultyInRandomBattles = true

  Tutorials = true
  AllowedToSkipBaseTutorials = true
  AllowedToSkipBaseTankTutorials = true
  EnableGoldPurchase = true
  EnablePremiumPurchase = true
  showPremiumAccount = true
  OnlineShopPacks = true
  ManuallyUpdateBalance = true //!!debug only
  PaymentMethods = true

  Items = false
  ItemsShop = true
  Wagers = true
  ItemsRoulette = false
  BattleTasks = false
  BattleTasksHard = true
  ItemsShopInTopMenu = true
  ItemModUpgrade = false
  ModUpgradeDifference = false

  BulletParamsForAirs = disable_network()

  TankDetailedDamageIndicator = disable_network()
  ShipDetailedDamageIndicator = disable_network()

  ActiveScouting = false

  PromoBlocks = true
  ShowAllPromoBlocks = disable_network()
  ShowAllBattleTasks = false

  ExtendedCrewSkillsDescription = disable_network()
  UnitInfo = true
  WikiUnitInfo = true
  ExpertToAce = false
  repairCostUsesPlayTime = false

  HiddenLeaderboardRows = false
  LiveStats = false
  streakVoiceovers = disable_network()
  SpectatorUnitDmgIndicator = disable_network()

  ProfileMedals = true
  UserCards = true
  SlotbarShowBattleRating = true
  GlobalShowBattleRating = false
  VideoPreview = disable_network()

  ClanRegions = false
  ClanAnnouncements = false
  ClanLog = false
  ClanActivity = false
  ClanSeasonRewardsLog = false
  ClanSeasons_3_0 = false
  ClanChangedInfoData = false
  ClanSquads = false
  ClanVehicles = false

  Warbonds = false
  WarbondsShop = false
  ItemConvertToWarbond = false
  ItemConvertToWarbondMultiple = false

  DisableSwitchPresetOnTutorialForHotas4 = false

  MissionsChapterHidden = disable_network()
  MissionsChapterTest = disable_network()

  ChinaForbidden = true //feature not allowed for china only
  ClanBattleSeasonAvailable = true

  CheckTwoStepAuth = false
  CheckGaijinPass = false

  AerobaticTricolorSmoke = disable_network()

  XRayDescription = disable_network()

  ControlsDeviceChoice = true
  ControlsAdvancedSettings = true
  ControlsPresets = true
  ControlsHelp = true

  SeparateTopMenuButtons = false

  HitCameraTargetStateIconsTank = false

  AllowExternalLink = true
  TankAltCrosshair = false

  DebriefingBattleTasks = false
  PromoBattleTasksRadioButtons = false

  XboxIngameShop = false
  XboxCrossConsoleInteraction = false
  Ps4XboxOneInteraction = false
  EnableMouse = true

  NewUnitTypeToBattleTutorial = false
  AchievementsUrl = false

  AllowSteamAccountLinking = true
  AllowXboxAccountLinking = false

  MapPreferences = false
  Tournaments = true

  PS4CrossNetwork = false

  everyDayLoginAward = true
  DebugLogPS4ShopData = false //For debug purpose, to see ps4 shop data on retail console
  Changelog = false
  ShowUrlQrCode = false

  ConsoleSeparateLeaderboards = false
  ConsoleSeparateEventsLeaderboards = false
  ConsoleSeparateWWLeaderboards = false
  WWOperationsList = false
  ShowDropChanceInTrophy = false

  FpsCounterOverride = false
  BulletAnimation = true
  BuyAllPresets = false
  enableFollowBulletCamera = disable_network()
  ProtectionMap = false
  CrewMap = true
  OrderAutoActivate = false
  WeaponryCustomPresets = false
  BattleAutoStart = false

  PS5HeadTracking = false
  replayRewind = false

  DamageControl = false

  ProtectionAnalysisShowTorpedoes = false
  ProtectionAnalysisShowBombs = false

  ResearchHelicopterOnGroundVehicle = false
  CaptchaAllowed = false
  DevShopMode = false
  CustomNicks = false
  Wishlist = false
  optionRT = has_ray_query()
  amdfsr = true
  HitsAnalysis = false

  optionBVH = true
  optionBVH_AO = true
  optionBVH_SM = true
  optionGFXAPI = true
  optionGFXAPIVulkan = true
  optionConsolePreset = true
})

let override = Watched({})
let cache = {}

defaults.subscribe(@(...) cache.clear())

function hasFeatureBasic(name) {
  local res = override.value?[name] ?? cache?[name]
  if (res != null)
    return res

  res = defaults.value?[name] ?? false
  if (!disable_network())
    res = local_player_has_feature(name, res)

  cache[name] <- res
  return res
}

function getFeaturePack(name) {
  let sBlk = get_game_settings_blk()
  let featureBlk = sBlk?.features[name]
  if (!isDataBlock(featureBlk))
    return null
  return featureBlk?.reqPack
}

function hasFeature(name) {
  if (name in cache)
    return cache[name]

  local confirmingResult = true
  local baseName = name
  if (name.len() > 1 && name.slice(0, 1) == "!") {
    confirmingResult = false
    baseName = name.slice(1, name.len())
  }
  let res = hasFeatureBasic(baseName) == confirmingResult
  cache[name] <- res
  return res
}

function hasAllFeatures(arr) {
  if (arr == null || arr.len() <= 0)
    return true

  foreach (name in arr)
    if (name && !hasFeature(name))
      return false

  return true
}

function hasAnyFeature(arr) {
  if (arr == null || arr.len() <= 0)
    return true

  foreach (name in arr)
    if (name && hasFeature(name))
      return true

  return false
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) cache.clear()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  defaults
  override

  getFeaturePack
  hasFeature
  hasAllFeatures
  hasAnyFeature
}
