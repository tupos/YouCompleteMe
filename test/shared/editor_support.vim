" Shared editor-version and feature-support policy tests.

let s:repository_directory = fnamemodify(
      \ resolve( expand( '<sfile>:p' ) ),
      \ ':h:h:h' )
execute 'set runtimepath^=' . fnameescape( s:repository_directory )


function! Test_EditorSupport_CurrentEditorIsSupported() abort
  call assert_match(
        \ '^\d\+\.\d\+\%(\.\d\+\)\?$',
        \ youcompleteme#editor_support#MinimumVersion() )
  call assert_true(
        \ youcompleteme#editor_support#Supported() )
endfunction


function! Test_EditorSupport_KnownFeaturesReturnSupportStatus() abort
  let features = [
        \ 'completion_info_popup',
        \ 'finder',
        \ 'hierarchy',
        \ 'semantic_highlighting',
        \ 'signature_help',
        \ 'virtual_text',
        \ ]

  for feature in features
    call assert_equal(
          \ v:t_bool,
          \ type(
          \   youcompleteme#editor_support#FeatureSupported(
          \     feature ) ) )
  endfor
endfunction


function! Test_EditorSupport_RejectsUnknownFeature() abort
  try
    call youcompleteme#editor_support#FeatureSupported(
          \ 'unknown' )
    call assert_report(
          \ 'An unknown editor feature was accepted' )
  catch /^Unknown YCM editor feature: unknown$/
  endtry
endfunction
