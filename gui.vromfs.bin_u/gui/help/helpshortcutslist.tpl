<<#rows>>
controlsHelpFrame {
  width:t='pw'
  class:t='inFrame'
  margin-bottom:t='1'

  tdiv {
    size:t='pw,ph'
    pos:t='0, 0.5ph-0.5h'; position:t='relative';
    flow:t='h-flow'
    padding:t='2'

    tdiv {
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      min-width:t='@kbh'
      margin-right:t='0.01@sf';
      <<@shortcutMarkup>>
    }

    textareaNoTab {
      id:t='text';
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      width:t='fw'
      controlsHelp:t='yes'
      text:t='<<text>>'
    }
  }
}
<</rows>>