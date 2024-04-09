tdiv {
  animated:t='yes'
  position:t='absolute'
  width:t='0'
  height:t='0'

  rotation:t='<<angle>>'

  behaviour:t='basicPos'
  left:t='<<startX>>*sw/100'
  top:t='<<startY>>*sh/100'
  left-base:t='<<startX>>'
  top-base:t='<<startY>>'
  left-end:t='<<endX>>'
  top-end:t='<<endY>>'
  pos-time:t='<<posTime>>'
  pos-scale:t='screen'
  pos-func:t='linear'
  pos-backfunc:t='square'
  pos-delay:t='<<posDelay>>'

  tdiv {
    position:t='absolute'
    background-image:t='!#ui/images/chests/fx_ray'
    background-color:t='#FFFFFF'
    width:t='0'
    height:t='0'

    behaviour:t='basicSize'
    width-base:t='0.01'
    height-base:t='<<hp>>'
    width-end:t='<<wp>>'
    height-end:t='<<hp>>'
    size-func:t='linear'
    size-scale:t='screen'
    size-time:t='<<sizeTime>>'
    size-delay:t='<<delay>>'

    behaviour:t='basicTransparency'
    transp-base:t='255'
    transp-end:t='0'
    transp-time:t='<<trTime>>'
    transp-delay:t='<<trDelay>>'
  }
}