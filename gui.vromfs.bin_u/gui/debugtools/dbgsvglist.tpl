tdiv {
  size:t='@rw, @rh'
  pos:t='sw/2-w/2, sh/2-h/2'
  position:t='root'
  flow:t='vertical'
  <<#bgColor>>background-color:t='<<bgColor>>'<</bgColor>>

  tdiv {
    size:t='pw, fh'
    flow:t='h-flow'
    flow-align:t='center'
    text-halign:t='center'
    margin:t='1@blockInterval'
    overflow-y:t='auto'

    activeText {
      width:t='pw'
      margin-bottom:t='1@blockInterval'
      caption:t='yes'
      text:t='<<title>>'
    }

    <<#files>>
    tdiv {
      width:t='<<size>> $max 180@sf/@pf'
      flow:t='vertical'
      margin:t='1@blockInterval'

      behaviour:t='button'
      on_click:t='onImgClick'
      imgPath:t='<<image>>'

      tdiv {
        id:t='image'
        size:t='<<size>>, <<size>>'
        max-width:t='512@sf/@pf'
        max-height:t='512@sf/@pf'
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        background-color:t='@white'
        background-image:t='<<image>>'
        background-svg-size:t='<<size>>, <<size>>'
        background-repeat:t='aspect-ratio'
        border:t='yes'
        border-color:t='#40404040'
      }
      activeText {
        text:t='<<name>>'
        pos:t='50%pw-50%w, 1@blockInterval'
        position:t='relative'
        tinyFont:t='yes'
      }
    }
    <</files>>
  }
}