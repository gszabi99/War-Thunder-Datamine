tdiv {
  id:t='<<id>>'
  position:t='absolute'
  pos:t='<<posX>>, <<posY>>'
  tdiv {
    position:t='absolute'
    pos:t='-w/2, -h/2'
    size:t='<<icWidth>>, <<icHeight>>'
    background-image:t='<<icon>>'
    background-color:t='#FFFF6600'

    behaviour:t='basicTransparency'
    transp-base:t='0'
    blend-time:t='0'
    transp-func:t='sinInOut'
    transp-end:t='255'
    transp-cycled:t='yes'
    transp-time:t='1300'
  }
  <<#outlineIcon>>
  tdiv {
    position:t='absolute'
    size:t='<<icWidth>>, <<icHeight>>'
    tdiv {
      position:t='absolute'
      pos:t='-w/2, -h/2'
      color-factor:t='0'

      background-image:t='<<outlineIcon>>'
      background-color:t='#FFFF6600'

      behaviour:t='basicTransparency'
      transp-base:t='255'
      transp-func:t='cube'
      transp-end:t='0'
      transp-time:t='800'
      transp-delay:t='500'
      transp-cycle-delay:t='500'
      transp-cycled:t='yes'

      behaviour:t='basicSize'
      width-base:t='100'
      height-base:t='100'
      width-end:t='160'
      height-end:t='160'
      size-func:t='linear'
      size-scale:t='parent'
      size-time:t='800'
      size-delay:t='500'
      blend-time:t='0'
      size-cycle-delay:t='500'
      size-cycled:t='yes'
    }
  }
  <</outlineIcon>>
}
