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
    pos:t='0, 0.8ph - h'
    position:t='absolute'
    background-repeat:t='aspect-ratio'
    background-image:t='<<supportUnitImage>>'
    background-svg-size:t='pw, ph'
  }

  img {
   size:t='pw, ph'
   position:t='absolute'
   <<#isSpawn>>
   background-image:t='#ui/gameuiskin#launcher_spawn_arrow.avif'
   <</isSpawn>>
   <<^isSpawn>>
   background-image:t='#ui/gameuiskin#launcher_change.avif'
   <</isSpawn>>
   background-svg-size:t='pw, ph'
  }
}