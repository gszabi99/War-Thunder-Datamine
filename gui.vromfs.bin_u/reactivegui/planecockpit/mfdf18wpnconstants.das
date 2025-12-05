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

struct Stations
  pos = fixed_array(
    float2(-0.000, -0.000), // 00
    float2(-0.370, -0.045), // 01 Wingtip station left
    float2(-0.370, -0.045), // 01 TEMP
    float2(-0.258, -0.065), // 02
    float2(-0.155, -0.113), // 03
    float2(-0.080, -0.240), // 04
    float2(-0.000, -0.180), // 05 Centerline
    float2(0.080, -0.240),  // 06
    float2(0.155, -0.113),  // 07
    float2(0.258, -0.065),  // 08
    float2(0.370, -0.045),  // 09 TEMP
    float2(0.370, -0.045))  // 09 Wingtip station right
  lblOffset = fixed_array(
    float2(-0.000, -0.000), // 00
    float2(-0.000, -0.055), // 01 Wingtip station left
    float2(-0.000, -0.055), // 01 TEMP
    float2(-0.000,  0.030), // 02
    float2(-0.000,  0.030), // 03
    float2(-0.045, -0.000), // 04
    float2(0.000, -0.000),  // 05 Centerline
    float2(0.045, -0.000),  // 06
    float2(0.000,  0.030),  // 07
    float2(0.000,  0.030),  // 08
     float2(0.000, -0.055), // 09 TEMP
    float2(0.000, -0.055))  // 09 Wingtip station right
