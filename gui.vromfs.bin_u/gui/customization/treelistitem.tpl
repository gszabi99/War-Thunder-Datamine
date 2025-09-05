<<#items>>
tdiv {
  id:t='<<item_id>>'
  position:t='relative'
  width:t='pw'
  flow:t='vertical'
  min-height:t='35@sf/@pf'
  isCollapsed:t='no'

  textarea {
    size:t='pw, ph'
    padding-left:t='<<paddingMult>>*25@sf/@pf'
    text:t='<<text>>'
  }
  <<#isChapter>>
  listbox {
    id:t='branch_list'
    isInited:t='no'
    display:t='hide'

    flow:t='vertical'
    width:t='pw'
    <<^onBranchSelect>>
      on_click:t='onBranchSelect'
    <</onBranchSelect>>
    <<#onBranchSelect>>
      on_click:t='<<onBranchSelect>>'
    <</onBranchSelect>>

    always-send-select:t='yes'
  }
  <</isChapter>>
}
<</items>>