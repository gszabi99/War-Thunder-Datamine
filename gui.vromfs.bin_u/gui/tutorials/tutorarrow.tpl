<<#arrows>>
tdiv {
  size:t='1@tutorArrowSize, 3@tutorArrowSize'
  left:t='<<left>>'
  top:t='<<top>>'
  position:t='absolute'

  tdiv {
    size:t='pw, ph-pw'

    tdiv {
      size:t='pw, pw'
      position:t='absolute'

      re-type:t='rotation'
      rotation:t='<<rotation>>'
      background-color:t='#417927'
      background-image:t='#ui/gameuiskin#arrow_tutor.svg'
      background-svg-size:t='@tutorArrowSize, @tutorArrowSize'
      background-repeat:t='stretch'

      behaviour:t='basicPos'
      top-base:t='0'
      top-end:t='100'
      pos-scale:t='parent'
      pos-func:t='sin'
      pos-time:t='1000'
      pos-cycled:t='yes'
      _pos-timer:t='0'
    }
  }
}
<</arrows>>
