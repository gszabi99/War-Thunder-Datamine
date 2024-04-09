tdiv {
  pos:t='0.5pw , 0.5ph'
  size:t='0, 0'
  position:t='absolute'
  overflow:t='visible'

  <<#outRays>>
    include "%gui/items/chestOpenFxRay.tpl"
  <</outRays>>
}

tdiv {
  size:t='1@chestRewardWidth, 1@chestRewardHeight'
  position:t='absolute'
  overflow:t='visible'
  pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
  tdiv {
    id:t='open_chest_anim_icon'
    size:t='0.8pw, 0.8ph'
    pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
    position:t='absolute'

    background-image:t='<<chestIcon>>'
    background-repeat:t='aspect-ratio'
    bgcolor:t="#FFFFFF"

    behaviour:t='basicTransparency'
    transp-base:t='255'
    transp-func:t='cube'
    transp-end:t='0'
    transp-time:t='250'
    transp-delay:t='450'
  }
}

tdiv {
  pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
  size:t='pw, ph'
  position:t='absolute'
  overflow:t='visible'
  behaviour:t='Timer'

  tdiv {
    pos:t='0.5pw , 0.5ph'
    size:t='0, 0'
    position:t='absolute'
    overflow:t='visible'

    tdiv {
      position:t='absolute'
      pos:t='0, 0'
      size:t='0, 0'
      behaviour:t='basicRotation'
      rot-base:t='0'
      rot-end:t='1080'
      rot-func:t='cube'
      rot-time:t='1000'
      rot-delay:t='0'

      tdiv {
        position:t='absolute'
        size:t='1@chestRewardWidth, 1@chestRewardWidth'
        overflow:t='visible'
        pos:t='-w/2, -h/2'

        tdiv {
          pos:t='pw/2 - w/2, ph/2 - h/2'
          width:t='1.2pw'
          height:t='1.2ph'
          position:t='absolute'
          background-image:t='!#ui/images/chests/chest_top_cloud'
          background-color:t='#FFFFFF'
          color-factor:t="0"

          behaviour:t='basicTransparency'
          transp-base:t='0'
          transp-func:t='cube'
          transp-end:t='255'
          transp-time:t='500'
          transp-delay:t='0'

          behaviour:t='basicSize'
          width-base:t='120'
          height-base:t='120'
          width-end:t='0'
          height-end:t='0'
          size-func:t='cube'
          size-scale:t='parent'
          size-time:t='500'
          size-delay:t='500'
        }

        tdiv {
          pos:t='pw/2 - w/2, ph/2 - h/2'

          width:t='1.5pw'
          height:t='1.5ph'
          position:t='absolute'
          background-image:t='!#ui/images/chests/chest_bg_cloud'
          background-color:t='#FFFFFF'
          color-factor:t="0"

          behaviour:t='basicTransparency'
          transp-base:t='0'
          transp-func:t='cube'
          transp-end:t='255'
          transp-time:t='500'
          transp-delay:t='0'

          behaviour:t='basicSize'
          width-base:t='150'
          height-base:t='150'
          width-end:t='0'
          height-end:t='0'
          size-func:t='cube'
          size-scale:t='parent'
          size-time:t='500'
          size-delay:t='500'
        }

        tdiv {
          pos:t='pw/2 - w/2, ph/2 - h/2'

          width:t='1.5pw'
          height:t='1.5ph'
          position:t='absolute'
          background-image:t='!#ui/images/chests/chest_bg_cloud'
          background-color:t='#FFFFFF'
          color-factor:t="0"

          behaviour:t='basicTransparency'
          transp-base:t='0'
          transp-func:t='cube'
          transp-end:t='255'
          transp-time:t='500'
          transp-delay:t='0'

          behaviour:t='basicSize'
          width-base:t='150'
          height-base:t='150'
          width-end:t='0'
          height-end:t='0'
          size-func:t='cube'
          size-scale:t='parent'
          size-time:t='500'
          size-delay:t='500'
        }
      }
    }
  }
}
