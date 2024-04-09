img {
  id:t='chest_background_blink_anim'
  size:t='1.5pw, w'
  pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
  position:t='absolute'
  background-svg-size:t='256@sf/@pf, 256@sf/@pf'
  background-image:t='!#ui/gameuiskin#circle_gradient_white.avif'
  color-factor:t='0'

  behaviour:t='basicTransparency'
  transp-cycled:t='yes'
  transp-base:t='100'
  transp-end:t='255'
  transp-time:t='1500'
  transp-func:t='sin'
  transp-delay:t='2200'
}

tdiv {
  pos:t='0.5pw , 0.5ph'
  size:t='0, 0'
  position:t='absolute'
  overflow:t='visible'

  <<#rays>>
    include "%gui/items/chestOpenFxRay.tpl"
  <</rays>>

  tdiv {
    position:t='absolute'
    size:t='1@chestRewardWidth, 1@chestRewardWidth'

    tdiv {
      id:t='chest_top_fx_cloud'
      pos:t='-w/2, -h/2'
      width:t='0'
      height:t='0'
      position:t='absolute'
      background-image:t='!#ui/images/chests/chest_top_cloud'
      background-color:t='#FFFFFFFF'

      behaviour:t='basicTransparency'
      transp-base:t='255'
      transp-func:t='cube'
      transp-end:t='0'
      transp-time:t='250'
      transp-delay:t='650'

      behaviour:t='basicRotation'
      rot-base:t='90'
      rot-end:t='760'
      rot-func:t='linear'
      rot-time:t='800'
      rot-delay:t='150'

      behaviour:t='basicSize'
      width-base:t='0'
      height-base:t='0'
      width-end:t='120'
      height-end:t='120'
      size-func:t='sinInOut'
      size-scale:t='parent'
      size-time:t='800'
      size-delay:t='150'
    }
  }

  tdiv {
    position:t='absolute'
    size:t='1@chestRewardWidth, 1@chestRewardWidth'

    tdiv {
      pos:t='-w/2, -h/2'
      width:t='0'
      height:t='0'
      position:t='absolute'
      background-image:t='!#ui/images/chests/chest_bg_cloud'
      background-color:t='#FFFFFF'

      behaviour:t='basicTransparency'
      transp-base:t='255'
      transp-func:t='cube'
      transp-end:t='0'
      transp-time:t='250'
      transp-delay:t='750'

      behaviour:t='basicSize'
      width-base:t='1'
      height-base:t='1'
      width-end:t='180'
      height-end:t='180'
      size-func:t='cube'
      size-scale:t='parent'
      size-time:t='750'
      size-delay:t='0'
    }

    tdiv {
      pos:t='-w/2, -h/2'
      width:t='1.5pw'
      height:t='1.5ph'
      position:t='absolute'
      background-image:t='!#ui/images/chests/chest_bg_cloud'
      background-color:t='#FFFFFF'
      color-factor:t='0'
  
      behaviour:t='basicTransparency'
      transp-base:t='0'
      transp-func:t='sinInOut'
      transp-end:t='255'
      transp-time:t='600'
      transp-delay:t='550'
    }

  }
}

tdiv {
  size:t='1@chestRewardWidth, 1@chestRewardHeight'
  position:t='absolute'
  overflow:t='visible'
  pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
  css-hier-invalidate:t="yes"
  tdiv {
    id:t='show_chest_anim_icon'
    pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
    position:t='absolute'
    background-color:t='#FFFFFF'
    width:t='0'
    height:t='0'

    behaviour:t='basicSize'
    width-base:t='150'
    height-base:t='150'
    width-end:t='80'
    height-end:t='80'
    size-func:t='quadAndCos'
    size-scale:t='parent'
    size-time:t='1000'
    size-delay:t='300'

    background-image:t="<<chestIcon>>"
    background-repeat:t="aspect-ratio"
    bgcolor:t="#FFFFFF"

    behaviour:t='basicTransparency'
    transp-base:t='0'
    transp-func:t='linear'
    transp-end:t='255'
    transp-time:t='300'
    transp-delay:t='300'
  }
}