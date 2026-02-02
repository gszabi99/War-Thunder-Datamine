tdiv {
  id:t='<<containerId>>'
  position:t='relative'
  width:t='pw'
  left:t='(pw-w)/2'
  flow:t='vertical'
  css-hier-invalidate:t='yes'

  <<#hasUnitImage>>
  tdiv {
    position:t='relative'
    flow:t='h-flow'
    flow-align:t='center'
    width:t='pw'
    left:t='(pw-w)/2'
    css-hier-invalidate:t='yes'
    <<#unitsImages>>
      include "%gui/profile/showcase/unitImage.tpl"
    <</unitsImages>>
  }
  <</hasUnitImage>>

  tdiv {
    position:t='relative'
    width:t='pw'
    flow:t='vertical'
    <<#textStats>>
      include "%gui/profile/showcase/textStat.tpl"
    <</textStats>>
  }

  <<#hasFlags>>
  tdiv {
    position:t='relative'
    flow:t='horizontal'
    left:t='(pw-w)/2'
    margin-y:t='<<scale>>*1@showcaseLinePadding'
    <<#flags>>
    tdiv {
      flow:t='vertical'
      <<#hasLeftMargin>>
      margin-left:t='<<scale>>*8@sf/@pf'
      <</hasLeftMargin>>

      tdiv {
        size:t='<<scale>>*60@sf/@pf, <<scale>>*0.66*60@sf/@pf'
        css-hier-invalidate:t='yes'
        background-color:t='#FFFFFF'
        background-image:t='<<flag>>'
        background-svg-size:t='<<scale>>*60@sf/@pf, <<scale>>*0.66*60@sf/@pf'
        background-repeat:t='aspect-ratio'
      }
      blankTextArea {
        position:t='relative'
        font:t='@fontSmall'
        font-pixht:t='<<scale>>*22@sf/@pf \ 1'
        left:t='(pw-w)/2'
        text-align:t='center'
        color:t='#FFFFFF'
        text:t='<<value>>'
        input-transparent:t='yes'
      }
    }
    <</flags>>
  }
  <</hasFlags>>
}