<<#plates>>
  modBlockHeader {
    width:t='<<w>>'
    pos:t='<<x>>, 0'
    class:t='flat'
    text {
      text:t='<<title>>'
      width:t='pw'
      top:t='ph/2-h/2'
      text-align:t='center'
      position:t='absolute'
    }
  }
<</plates>>

<<#separators>>
  tdiv {
    size:t='1@dp, ph -6@dp'
    pos:t='<<x>>-w/2, ph/2-h/2'
    position:t='absolute'
    background-color:t='@tableHeaderSeparatorColor'
  }
<</separators>>


