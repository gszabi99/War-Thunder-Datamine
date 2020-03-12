tdiv {
  width:t='@rw'
  max-height:t='@rh'
  pos:t='50%sw-50%w, 50%sh-50%h'
  position:t='root'
  overflow-y:t='auto'
  flow:t='vertical'
  flow-align:t='left'

  <<#tipsList>>
  tdiv {
    width:t='pw - 0.06@sf'
    margin:t='0.01@sf, 0.01@sf'
    behaviour:t='bhvHint'
    value:t='<<value>>'
    isWrapInRowAllowed:t='yes'
  }
  <</tipsList>>
}