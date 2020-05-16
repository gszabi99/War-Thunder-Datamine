qrBackground {
  size:t='<<qrSize>>, <<qrSize>>'
  padding:t='4*<<cellSize>>'
  background-color:t='@white'

  tdiv {
    <<#qrBlocks>>
    qrBlock {
      size:t='<<blockSize>>'
      pos:t='<<blockPos>>'
      position:t='absolute'
      background-color:t='@black'
    }
    <</qrBlocks>>
  }
}