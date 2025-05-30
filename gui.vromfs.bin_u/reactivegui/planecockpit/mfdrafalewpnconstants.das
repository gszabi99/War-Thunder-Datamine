require %rGui.utils.poly_shape_common

require DagorMath

struct Colors
  black   : E3DCOLOR = E3DCOLOR(Color4(float4(0.000, 0.000, 0.000, 1.000))) //#000000
  blue    : E3DCOLOR = E3DCOLOR(Color4(float4(0.000, 0.000, 1.000, 1.000))) //#0000FF
  green   : E3DCOLOR = E3DCOLOR(Color4(float4(0.000, 1.000, 0.000, 1.000))) //#00FF00
  orange  : E3DCOLOR = E3DCOLOR(Color4(float4(1.000, 0.118, 0.000, 1.000))) //#FF1E00
  purple  : E3DCOLOR = E3DCOLOR(Color4(float4(0.784, 0.000, 1.000, 1.000))) //#C800FF
  red     : E3DCOLOR = E3DCOLOR(Color4(float4(1.000, 0.000, 0.000, 1.000))) //#FF0000
  white   : E3DCOLOR = E3DCOLOR(Color4(float4(1.000, 1.000, 1.000, 1.000))) //#FFFFFF
  yellow  : E3DCOLOR = E3DCOLOR(Color4(float4(1.000, 1.000, 0.000, 1.000))) //#FFFF00

struct Stations
  pos = [
    float2(-0.000,  0.000),  // Unknown
    float2(-0.454,  0.169),  // Left wingtip
    float2(-0.367,  0.129),  // Left wing
    float2(-0.282,  0.080),  // Left wing
    float2(-0.185,  0.026),  // Left wing
    float2(-0.082,  0.190),  // Left fuselage aft
    float2(0.063, -0.233),   // Right fuselage fwd
    float2(0.000,  0.033),   // Centerline fuselage
    float2(0.082,  0.190),   // Right fuselage aft
    float2(0.185,  0.026),   // Right wing
    float2(0.282,  0.080),   // Right wing
    float2(0.367,  0.129),   // Right wing
    float2(0.454,  0.169),   // Right wingtips
  ]
  offsetAam = [
    float2(0.000,  0.000),   // Unknown
    float2(0.000, -0.101),   // Left wingtip
    float2(0.000, -0.087),   // Left wing
    float2(0.000, -0.070),   // Left wing
    float2(0.000,  0.000),   // Left wing
    float2(0.000, -0.037),   // Left fuselage aft
    float2(0.000,  0.000),   // Right fuselage fwd
    float2(0.000,  0.000),   // Centerline fuselage
    float2(0.000, -0.037),   // Right fuselage aft
    float2(0.000,  0.000),   // Right wing
    float2(0.000, -0.070),   // Right wing
    float2(0.000, -0.087),   // Right wing
    float2(0.000, -0.101),   // Right wingtips
  ]

struct SafetyIndicators
  y = [
    0.000, // Unknown
    0.254, // Left wingtip
    0.254, // Left wing
    0.310, // Left wing
    0.000, // Left wing
    0.308, // Left fuselage aft
    0.308, // Right fuselage fwd
    0.245, // Centerline fuselage
    0.308, // Right fuselage aft
    0.000, // Right wing
    0.310, // Right wing
    0.254, // Right wing
    0.254, // Right wingtips
 ]

struct StationIndicators
  pos = [
    float2(-0.454,  0.169),  // Left wingtip
    float2(-0.367,  0.129),  // Left wing
    float2(-0.282,  0.080),  // Left wing
    float2(-0.185,  0.026),  // Left wing
    float2(-0.082,  0.190),  // Left fuselage aft
    float2(-0.063, -0.233),  // Left fuselage fwd
    float2(0.000, -0.069),   // Centerline fuselage aft
    float2(0.000,  0.052),   // Centerline fuselage fwd
    float2(0.063, -0.233),   // Right fuselage fwd
    float2(0.082,  0.190),   // Right fuselage aft
    float2(0.185,  0.026),   // Right wing
    float2(0.282,  0.080),   // Right wing
    float2(0.367,  0.129),   // Right wing
    float2(0.454,  0.169),   // Right wingtip
  ]

struct Mica
  body = Poly(
  [
    float2(0.000, -0.500),

    float2(-0.043, -0.390),
    float2(-0.043,  0.500),

    float2(0.043,  0.500),
    float2(0.043, -0.390),
  ], ShapeType.Poly, float2(0.0), float2(1.0))

  seeker = Poly(
  [
    float2(0.000, -0.500),

    float2(-0.043, -0.390),
    float2(-0.043, -0.370),

    float2(0.043, -0.370),
    float2(0.043, -0.390),
  ], ShapeType.PolyFilledOutlined, float2(0.0), float2(1.0))

  strake = Poly(
  [
    float2(-0.043, -0.115),
    float2(-0.068, -0.096),
    float2(-0.068,  0.239),
    float2(-0.043,  0.251),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))

  fin = Poly(
  [
    float2(-0.043,  0.309),
    float2(-0.110,  0.371),
    float2(-0.110,  0.394),
    float2(-0.043,  0.432),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))


struct Outline
  main = Poly(
  [
    float2(-0.059, -0.414),
    float2(-0.093, -0.332),
    float2(-0.092, -0.214),
    float2(-0.138, -0.202),
    float2(-0.163, -0.119),
    float2(-0.462,  0.128),
    float2(-0.467,  0.211),
    float2(-0.094,  0.239),
    float2(-0.069,  0.325),

    float2(0.069,  0.325),
    float2(0.094,  0.239),
    float2(0.467,  0.211),
    float2(0.462,  0.128),
    float2(0.163, -0.119),
    float2(0.138, -0.202),
    float2(0.092, -0.214),
    float2(0.093, -0.332),
    float2(0.059, -0.414),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))

  canard = Poly(
  [
    float2(-0.093, -0.332),
    float2(-0.092, -0.214),
    float2(-0.203, -0.184),
    float2(-0.203, -0.224),
  ], ShapeType.Poly, float2(0.0), float2(1.0))


struct Tank
  tank = Poly(
  [
    float2(-0.008, -0.475),
    float2(-0.023, -0.472),
    float2(-0.038, -0.467),
    float2(-0.052, -0.459),
    float2(-0.065, -0.450),
    float2(-0.076, -0.438),
    float2(-0.086, -0.424),
    float2(-0.093, -0.409),
    float2(-0.098, -0.389),
    float2(-0.100, -0.372),
    float2(-0.100,  0.118),
    float2(-0.014,  0.472),

    float2(0.014,  0.472),
    float2(0.100,  0.118),
    float2(0.100, -0.372),
    float2(0.098, -0.389),
    float2(0.093, -0.409),
    float2(0.086, -0.424),
    float2(0.076, -0.438),
    float2(0.065, -0.450),
    float2(0.052, -0.459),
    float2(0.038, -0.467),
    float2(0.023, -0.472),
    float2(0.008, -0.475),
  ], ShapeType.Poly, float2(0.0), float2(1.0))

  fin = Poly(
  [
    float2(-0.048,  0.333),
    float2(-0.072,  0.333),
    float2(-0.072,  0.454),
    float2(-0.018,  0.454),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))


struct TargetingPod
  optic = Poly(
  [
    float2(-0.078, -0.209),
    float2(-0.078, -0.294),
    float2(-0.090, -0.302),
    float2(-0.102, -0.310),
    float2(-0.113, -0.322),
    float2(-0.121, -0.338),
    float2(-0.125, -0.356),
    float2(-0.125, -0.378),
    float2(-0.119, -0.403),
    float2(-0.110, -0.421),
    float2(-0.101, -0.435),
    float2(-0.089, -0.449),
    float2(-0.072, -0.464),
    float2(-0.047, -0.477),
    float2(-0.028, -0.483),
    float2(-0.009, -0.486),

    float2(0.009, -0.486),
    float2(0.028, -0.483),
    float2(0.047, -0.477),
    float2(0.072, -0.464),
    float2(0.089, -0.449),
    float2(0.101, -0.435),
    float2(0.110, -0.421),
    float2(0.119, -0.403),
    float2(0.125, -0.378),
    float2(0.125, -0.356),
    float2(0.121, -0.338),
    float2(0.113, -0.322),
    float2(0.102, -0.310),
    float2(0.090, -0.302),
    float2(0.078, -0.294),
    float2(0.078, -0.209),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))

  base = Poly(
  [
    float2(-0.078, -0.209),
    float2(-0.078,  0.495),
    float2(0.078,  0.495),
    float2(0.078, -0.209),
  ], ShapeType.Poly, float2(0.0), float2(1.0))


struct MultipleEjector
  multipleEjector = Poly(
  [
    // Top left
    float2(-0.009, -0.500),
    float2(-0.028, -0.497),
    float2(-0.046, -0.491),
    float2(-0.062, -0.483),
    float2(-0.077, -0.472),
    float2(-0.090, -0.459),
    float2(-0.101, -0.444),
    float2(-0.110, -0.427),
    float2(-0.115, -0.410),
    float2(-0.118, -0.391),
    // Bottom left
    float2(-0.118,  0.391),
    float2(-0.115,  0.410),
    float2(-0.110,  0.427),
    float2(-0.101,  0.444),
    float2(-0.090,  0.459),
    float2(-0.077,  0.472),
    float2(-0.062,  0.483),
    float2(-0.046,  0.491),
    float2(-0.028,  0.497),
    float2(-0.009,  0.500),
    // Bottom right
    float2(0.009,  0.500),
    float2(0.028,  0.497),
    float2(0.046,  0.491),
    float2(0.062,  0.483),
    float2(0.077,  0.472),
    float2(0.090,  0.459),
    float2(0.101,  0.444),
    float2(0.110,  0.427),
    float2(0.115,  0.410),
    float2(0.118,  0.391),
    // Top right
    float2(0.118, -0.391),
    float2(0.115, -0.410),
    float2(0.110, -0.427),
    float2(0.101, -0.444),
    float2(0.090, -0.459),
    float2(0.077, -0.472),
    float2(0.062, -0.483),
    float2(0.046, -0.491),
    float2(0.028, -0.497),
    float2(0.009, -0.500),
  ], ShapeType.Poly, float2(0.0), float2(1.0))


struct Bomb
  body = Poly(
  [
    float2(-0.004, -0.500),
    float2(-0.010, -0.499),
    float2(-0.016, -0.496),
    float2(-0.023, -0.489),
    float2(-0.030, -0.480),
    float2(-0.038, -0.464),
    float2(-0.118, -0.231),
    float2(-0.118,  0.239),
    float2(-0.038,  0.500),

    float2(0.038,  0.500),
    float2(0.118,  0.239),
    float2(0.118, -0.231),
    float2(0.038, -0.464),
    float2(0.030, -0.480),
    float2(0.023, -0.489),
    float2(0.016, -0.496),
    float2(0.010, -0.499),
    float2(0.004, -0.500),
  ], ShapeType.Poly, float2(0.0), float2(1.0))

  fin = Poly(
  [
    float2(-0.085,  0.347),
    float2(-0.185,  0.419),
    float2(-0.185,  0.500),
    float2(-0.038,  0.500),
  ], ShapeType.Poly, float2(0.0), float2(1.0))

  seeker = Poly(
  [
    float2(-0.004, -0.500),
    float2(-0.010, -0.499),
    float2(-0.016, -0.496),
    float2(-0.023, -0.489),
    float2(-0.030, -0.480),
    float2(-0.038, -0.464),
    float2(-0.086, -0.328),

    float2(0.086, -0.328),
    float2(0.038, -0.464),
    float2(0.030, -0.480),
    float2(0.023, -0.489),
    float2(0.016, -0.496),
    float2(0.010, -0.499),
    float2(0.004, -0.500),
  ], ShapeType.PolyFilledOutlined, float2(0.0), float2(1.0))

struct StatusIndicator
  w = Poly(
  [
    float2(0.02, -0.02),
    float2(0.01,  0.03),

    float2(0.00,  0.00),

    float2(-0.01,  0.03),
    float2(-0.02, -0.02),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))

  line = Poly(
  [
    float2(-0.01,  0.01),
    float2(0.01, -0.01),
  ], ShapeType.PolyLine, float2(0.0), float2(1.0))

struct Shapes
  mica = Mica()
  outline = Outline()
  tank = Tank()
  targetingPod = TargetingPod()
  multipleEjector = MultipleEjector()
  bomb = Bomb()
  statusIndicator = StatusIndicator()
