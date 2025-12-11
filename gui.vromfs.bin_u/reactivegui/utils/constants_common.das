require math
require DagorMath

let PI2 = 2.0 * PI
let PI_2 = 0.5 * PI
let PI_4 = 0.25 * PI
let PI3_4 = 0.75 * PI
let PI3_2 = 1.5 * PI

let degToRad = PI / 180.0
let radToDeg = 180.0 / PI

let SINCOS45 = 0.70710678118654752440084436210485

let mpsToKnots = 1.94384
let metrToFeet = 3.28084
let mpsToKmh = 3.6
let mpsToMh = 2.23694
let metrToMile = 0.000621371
let metrToNavMile = 0.000539957
let kmetrToNavMile = 0.539957
let NmToFt = 6076.11549
let mpsToFpm = 196.8504
let radPerSecToRpm = 60.f / (2. * PI)
let zeroKelvinInCelsium = -273.15;
let kgToPound = 2.205

let TRANSPARENT = E3DCOLOR(0x00000000)
let BLACK = E3DCOLOR(0xFF000000)
let WHITE = E3DCOLOR(0xFFFFFFFF)

let shared
  FT_TO_M = 0.3048
  M_TO_FT = 1.0 / FT_TO_M
  LBS_TO_KG = 0.45359237
  KG_TO_LBS = 1.0 / LBS_TO_KG
  KTS_TO_KPH = 1.852
  KPH_TO_KTS = 1.0 / KTS_TO_KPH
  MPS_TO_KPH = 3.6
  KPH_TO_MPS = 1.0 / MPS_TO_KPH
  MPS_TO_KTS = MPS_TO_KPH * KPH_TO_KTS
  KTS_TO_MPS = KTS_TO_KPH * KPH_TO_MPS
  FPM_TO_MPS = FT_TO_M / 60.0
  MPS_TO_FPM = 1.0 / FPM_TO_MPS

let radarModeNames = fixed_array<string>(
  "hud/standby",
  "hud/search",
  "hud/acquisition",
  "hud/ACM",
  "hud/HMD",
  "hud/BST",
  "hud/VSL",
  "hud/track",

  "hud/PD VS standby",
  "hud/PD VS search",
  "hud/PD VS acquisition",
  "hud/PD VS ACM",
  "hud/PD VS BST",
  "hud/PD VS VSL",

  "hud/PD HDN VS standby",
  "hud/PD HDN VS search",
  "hud/PD HDN VS acquisition",
  "hud/PD HDN VS ACM",
  "hud/PD HDN VS BST",
  "hud/PD HDN VS VSL",

  "hud/PD standby",
  "hud/PD search",
  "hud/PD acquisition",
  "hud/PD ACM",
  "hud/PD HMD",
  "hud/PD BST",
  "hud/PD VSL",
  "hud/PD track",
  "hud/PD RAM",

  "hud/PD HDN standby",
  "hud/PD HDN search",
  "hud/PD HDN acquisition",
  "hud/PD HDN ACM",
  "hud/PD HDN HMD",
  "hud/PD HDN BST",
  "hud/PD HDN VSL",
  "hud/PD HDN track",

  "hud/GTM standby",
  "hud/GTM search",
  "hud/GTM acquisition",
  "hud/GTM ACM",
  "hud/GTM BST",
  "hud/GTM VSL",
  "hud/GTM track",

  "hud/SEA standby",
  "hud/SEA search",
  "hud/SEA acquisition",
  "hud/SEA ACM",
  "hud/SEA BST",
  "hud/SEA VSL",
  "hud/SEA track",


  "hud/LD standby",
  "hud/LD search",
  "hud/LD acquisition",
  "hud/LD ACM",
  "hud/LD track",

  "hud/MTI standby",
  "hud/MTI search",
  "hud/MTI acquisition",
  "hud/MTI ACM",
  "hud/MTI track",

  "hud/TWS standby",
  "hud/TWS search",
  "hud/TWS acquisition",
  "hud/TWS ACM",
  "hud/TWS BST",
  "hud/TWS VSL",
  "hud/TWS track",

  "hud/TWS HDN standby",
  "hud/TWS HDN search",
  "hud/TWS HDN acquisition",
  "hud/TWS HDN ACM",
  "hud/TWS HDN BST",
  "hud/TWS HDN VSL",
  "hud/TWS HDN track",

  "hud/TWS GTM standby",
  "hud/TWS GTM search",
  "hud/TWS GTM acquisition",
  "hud/TWS GTM ACM",
  "hud/TWS GTM BST",
  "hud/TWS GTM VSL",
  "hud/TWS GTM track",

  "hud/TWS SEA standby",
  "hud/TWS SEA search",
  "hud/TWS SEA acquisition",
  "hud/TWS SEA ACM",
  "hud/TWS SEA BST",
  "hud/TWS SEA VSL",
  "hud/TWS SEA track",

  "hud/IRST standby",
  "hud/IRST search",
  "hud/IRST acquisition",
  "hud/IRST ACM",
  "hud/IRST HMD",
  "hud/IRST track",

  "hud/air_search",
  "hud/ground_search",

  "hud/auto acquisition",
  "hud/auto ACM",
  "hud/auto HMD",
  "hud/track memory")
