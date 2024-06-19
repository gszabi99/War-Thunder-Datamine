tdiv {
  pos:t='<<posX>>, 0'
  input-transparent:t='no'
  not-input-transparent:t='yes'
  color-factor:t='<<colorFactor>>'
  position:t='absolute'
  background-color:t='#FFFFFF'
  background-repeat:t='expand-svg'
  <<#isRed>>
    background-image:t='#ui/gameuiskin#shop_group_redgradient.svg'
  <</isRed>>
  <<^isRed>>
    background-image:t='#ui/gameuiskin#shop_group_bluegradient.svg'
  <</isRed>>

  background-svg-size:t='256@dp, 64@dp'
  background:t='yes'
  width:t='<<width>>'
  height:t='ph+1@dp'

  behaviour:t='basicTransparency'
  transp-base:t='0'
  transp-func:t='cube'
  transp-end:t='255'
  transp-time:t='250'
  _transp-timer:t='1'
}