tdiv {
  width:t='@rw'
  pos:t='50%sw-50%w, 50%sh-50%h'
  position:t='root'
  flow:t='vertical'
  text-halign:t='center'

  <<#bgColor>>background-color:t='<<bgColor>>'<</bgColor>>

  activeText {
    width:t='pw'
    margin-bottom:t='0.01@sf'
    caption:t='yes'
    textShade:t='yes'
    text:t='<<image>>'
  }

  <<#blocks>>
  tdiv {
    width:t='pw'
    flow:t="h-flow"
    flow-align:t='center'
    text-halign:t='center'

    activeText {
      width:t='pw'
      pos:t='0, 0.01@sf'
      position:t='relative'
      caption:t='yes'
      textShade:t='yes'
      text:t='<<header>>'
    }

    <<#sizeList>>
    tdiv {
      flow:t='vertical'
      margin:t='1@blockInterval'

      activeText {
        text:t='<<name>>'
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        textShade:t='yes'
      }
      tdiv {
        size:t='<<size>>, <<size>>'
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        background-color:t='@white'
        background-image:t='<<image>>:<<size>>:<<size>>:K'
        background-repeat:t='aspect-ratio'
        border:t='yes'
        border-color:t='#40404040'
      }
    }
    <</sizeList>>
  }
  <</blocks>>
}