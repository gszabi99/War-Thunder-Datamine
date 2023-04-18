div {  //header
  id:t='<<id>>'
  <<#isFullscreen>>
  size:t='sw, sh'
  position:t='root'
  <</isFullscreen>>
  <<^isFullscreen>>
  size:t='pw, ph'
  position:t='absolute'
  <</isFullscreen>>

  <<#darkBlocks>>
    <<darkBlock>>
    {
      size:t='<<size0>>, <<size1>>'
      pos:t='<<pos0>>, <<pos1>>'
      position:t='absolute'
      <<#onClick>>
        behaviour:t='button'
        _on_click:t='<<onClick>>'
        _on_r_click:t='<<onClick>>'
      <</onClick>>
    }
  <</darkBlocks>>
  <<#lightBlocks>>
    <<lightBlock>>
    {
      id:t='<<id>>'
      size:t='<<size0>>, <<size1>>'
      pos:t='<<pos0>>, <<pos1>>'
      position:t='absolute'
      <<#onClick>>
        behaviour:t='button'
        <<#isNoDelayOnClick>>
          on_click:t='<<onClick>>'
          on_r_click:t='<<onClick>>'
        <</isNoDelayOnClick>>
        <<^isNoDelayOnClick>>
          _on_click:t='<<onClick>>'
          _on_r_click:t='<<onClick>>'
        <</isNoDelayOnClick>>
        <<#accessKey>>
          accessKey:t='<<accessKey>>'
        <</accessKey>>
      <</onClick>>
    }
  <</lightBlocks>>
}
