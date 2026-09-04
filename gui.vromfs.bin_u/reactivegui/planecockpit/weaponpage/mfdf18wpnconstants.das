require DagorMath

struct Colors
  green = E3DCOLOR(Color4(float4(0.000, 1.000, 0.000, 1.000))) //#00FF00

struct Shapes
  outline = fixed_array(
    float2(-0.360, -0.050),
    float2(-0.050, -0.200),
    float2(-0.047, -0.240),
    float2(-0.053, -0.240))
  diamond = fixed_array(
    float2(-0.500,  0.000),
    float2(0.000, -0.500),
    float2(0.500,  0.000),
    float2(0.000,  0.500))

enum StationType
  F_18C
  F_18E

struct Stations
  pos : array<float2>
  lblOffset : array<float2>

struct StationsF18E : Stations
  override pos = array(
    float2(-0.000, -0.000), // 00
    float2(-0.370, -0.045), // 01 Wingtip station left
    float2(-0.292, -0.050), // 02
    float2(-0.208, -0.090), // 03
    float2(-0.120, -0.134), // 04
    float2(-0.080, -0.240), // 05
    float2(-0.000, -0.180), // 06 Centerline
    float2(0.080, -0.240),  // 07
    float2(0.120, -0.134),  // 08
    float2(0.208, -0.090),  // 09
    float2(0.292, -0.050),  // 10
    float2(0.370, -0.045))  // 11 Wingtip station right
  override lblOffset = array(
    float2(-0.000, -0.000), // 00
    float2(-0.000, -0.055), // 01 Wingtip station left
    float2(-0.000,  0.030), // 02
    float2(-0.000,  0.030), // 03
    float2(-0.000,  0.030), // 04
    float2(-0.045, -0.000), // 05
    float2(0.000, -0.000),  // 06 Centerline
    float2(0.045, -0.000),  // 07
    float2(0.000,  0.030),  // 08
    float2(0.000,  0.030),  // 09
    float2(0.000,  0.030),  // 10
    float2(0.000, -0.055))  // 11 Wingtip station right

struct StationsF18C : Stations
  override pos = array(
    float2(-0.000, -0.000), // 00
    float2(-0.370, -0.045), // 01 Wingtip station left
    float2(-0.258, -0.065), // 02
    float2(-0.155, -0.113), // 03
    float2(-0.080, -0.240), // 04
    float2(-0.000, -0.180), // 05 Centerline
    float2(0.080, -0.240),  // 06
    float2(0.155, -0.113),  // 07
    float2(0.258, -0.065),  // 08
    float2(0.370, -0.045))  // 09 Wingtip station right
  override lblOffset = array(
    float2(-0.000, -0.000), // 00
    float2(-0.000, -0.055), // 01 Wingtip station left
    float2(-0.000,  0.030), // 02
    float2(-0.000,  0.030), // 03
    float2(-0.045, -0.000), // 04
    float2(0.000, -0.000),  // 05 Centerline
    float2(0.045, -0.000),  // 06
    float2(0.000,  0.030),  // 07
    float2(0.000,  0.030),  // 08
    float2(0.000, -0.055))  // 09 Wingtip station right
