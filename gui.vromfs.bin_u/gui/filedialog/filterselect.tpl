<<#items>>
  option{
    id:t = '<<id>>'
    overflow:t = 'hidden';
    <<#isAllFiles>>
      text:t = '<<?filesystem/allFiles>> (*.*)'
    <</isAllFiles>>
    <<^isAllFiles>>
      text:t = '<<?filesystem/file>> <<fileExtensionUpper>> (*.<<fileExtension>>)'
    <</isAllFiles>>
    selected:t = '<<#selected>>yes<</selected>><<^selected>>no<</selected>>'
  }
<</items>>
ButtonImg{
  enable:t='no'
}
