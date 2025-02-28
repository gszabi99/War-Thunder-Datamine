<<#isOneInRow>>
tdiv {
  position:t='relative'
  width:t='pw'
  css-hier-invalidate:t='yes'
<</isOneInRow>>

button {
  id:t='<<id>>'
  imageIdx:t='<<imageIdx>>'
  unit:t='<<unit>>'
  position:t='relative'
  size:t='<<scale>>*<<width>> \ 1, <<scale>>*<<height>> \ 1'
  <<#isOneInRow>>
  left:t='(pw-w)/2'
  margin-bottom:t=''
  <</isOneInRow>>

  <<#margin>>
  margin:t='<<margin>>'
  <</margin>>

  <<#image>>
    background-image:t='<<image>>'
    background-repeat:t='aspect-ratio'
    background-color:t='#FFFFFF'
    background-svg-size:t='<<scale>>*<<width>> \ 1, <<scale>>*<<height>> \ 1'
  <</image>>
  <<^image>>
    background-image:t=''
  <</image>>

  <<#isDisabledInEditMode>>
    showInEditMode:t='no'
  <</isDisabledInEditMode>>

  <<#isForEditMode>>
    showInEditMode:t='yes'
    display:t='hide'
  <</isForEditMode>>

  on_click:t='onUnitImageClick'

  <<^isDisabledInEditMode>>
    tdiv {
      re-type:t='9rect'
      position:t='absolute'
      size:t='<<scale>>*<<width>> \ 1, <<scale>>*<<height>> \ 1'
      css-hier-invalidate:t='yes'
      background-color:t='#FFFFFF'
      background-image:t='!ui/images/profile/empty_unit_rect.svg'
      background-position:t='10, 10'
      background-svg-size:t='<<scale>>*<<width>> \ 1, <<scale>>*<<height>> \ 1'
      background-repeat:t='expand-svg'
      <<#image>>
      display:t='hide'
      <</image>>
      showInEditMode:t='yes'

      <<^image>>
      tdiv {
        position:t='absolute'
        size:t='<<scale>>*10@sf/@pf, <<scale>>*50@sf/@pf'
        pos:t='(pw-w)/2, (ph-h)/2'
        background-color:t='#FFFFFF'
        display:t='hide'
        showInEditMode:t='yes'
      }
      tdiv {
        position:t='absolute'
        size:t='<<scale>>*50@sf/@pf, <<scale>>*10@sf/@pf'
        pos:t='(pw-w)/2, (ph-h)/2'
        background-color:t='#FFFFFF'
        display:t='hide'
        showInEditMode:t='yes'
      }
      <</image>>

      <<#image>>
      button {
        position:t='absolute'
        size:t='1@cIco, 1@cIco'
        pos:t='pw - w - 15@sf/@pf, ph - w - 15@sf/@pf'
        bgcolor:t='#FFFFFF'
        background-image:t='#ui/gameuiskin#icon_trash_bin.svg'
        background-svg-size:t='1@cIco, 1@cIco'
        not-input-transparent:t='yes'
        on_click:t='onDeleteUnitClick'
        imageIdx:t='<<imageIdx>>'
        interactive:t='yes'
        tooltip:t='#msgbox/btn_delete'
      }
      <</image>>
    }
  <</isDisabledInEditMode>>
}
<<#isOneInRow>>
}
<</isOneInRow>>