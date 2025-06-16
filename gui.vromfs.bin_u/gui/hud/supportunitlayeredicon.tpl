tdiv {
  size:t='pw, ph'
  <<#isSpawn>>
  img {
    size:t='pw, ph'
    position:t='absolute'
    background-image:t='#ui/gameuiskin#launcher_spawn.avif'
    background-svg-size:t='pw, ph'
  }
  <</isSpawn>>
  img {
    size:t='pw, 0.5pw'
    <<#isSpawn>>
    pos:t='0, 0.8ph - h'
    <</isSpawn>>
    <<^isSpawn>>
    pos:t='0, 0.5ph - 0.5h'
    <</isSpawn>>
    position:t='absolute'
    background-repeat:t='aspect-ratio'
    background-image:t='<<supportUnitImage>>'
    background-svg-size:t='pw, ph'
  }

  <<^isSlave>>
  img {
   position:t='absolute'
   <<#isSpawn>>
   size:t='pw, ph'
   background-image:t='#ui/gameuiskin#launcher_spawn_arrow.avif'
   background-svg-size:t='pw, ph'
   <</isSpawn>>
   <<#isChange>>
   size:t='pw, ph'
   background-image:t='#ui/gameuiskin#launcher_change.avif'
   background-svg-size:t='pw, ph'
   <</isChange>>
  }
  <</isSlave>>
}