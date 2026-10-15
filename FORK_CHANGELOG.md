# Fork changelog

This document records changes carried by the `tupos/YouCompleteMe` fork that
are not present in upstream YouCompleteMe. It covers both this repository and
the `tupos/ycmd` fork used through the `third_party/ycmd` submodule.

The current fork delta starts after these upstream merge bases:

- YouCompleteMe: `d4c91430b70a21ce471c8572400b647d313995b4`
- ycmd: `a290328810cec343fc4df23ff86936cfa7630687`

Update the merge bases and the entries below whenever upstream changes are
merged. Remove an entry once the corresponding change is available upstream.

## Current fork delta

### Neovim support

- Treat Neovim as a supported editor and document the versions required for
  the complete feature set.
- Provide native Neovim implementations for hover windows, inlay hints,
  semantic highlighting, the symbol finder, type and call hierarchies,
  signature help, detailed diagnostic windows, and diagnostic virtual text.
- Display completion information with Neovim's native completion popup.
- Centralize editor feature and minimum-version checks.
- Keep editor-independent behavior shared between Vim and Neovim while using
  text properties and popup windows in Vim, and extmarks and floating windows
  in Neovim.

### Language Server Protocol support

- Display and track LSP work-done progress, including connection generations,
  disconnect cleanup, and progress updates received while queues are full.
- Support generic LSP request cancellation in ycmd and expose cancellable HTTP
  operations to YCM.
- Cancel superseded completion, completion-resolution, signature-help,
  semantic-token, inlay-hint, document-highlight, and completer-command
  requests.
- Trace cancellable request lifecycles in both YCM and ycmd.
- Support `textDocument/documentHighlight` and automatically highlight the
  symbol under the cursor, including distinct text, read, and write kinds.
- Support `textDocument/prepareRename` and ask for a replacement name only
  after the language server confirms that the symbol can be renamed.
- Add `:YcmDisableLanguageServer [filetype]` and
  `:YcmEnableLanguageServer [filetype]`. With no filetype, these commands
  affect all language servers for the current editor session.

### Rendering and scrolling performance

- Coalesce scrolling feature requests so rapid scrolling does not create an
  unbounded sequence of obsolete requests.
- Preserve semantic highlights and inlay hints while replacement data is
  pending, and update only decorations whose rendered state changed.
- Batch Neovim decoration updates to reduce Python-provider round trips.
- Combine message polling and progress retrieval, and register message polls
  from editor events instead of continuously polling inactive buffers.
- Avoid refreshing unchanged document highlights.

### Reliability

- Serialize complete messages written concurrently to TCP language servers.
- Retry LSP requests safely after modified-document synchronization.
- Synchronize document contents before sending save notifications.
- Refresh diagnostics and semantic highlights after reloading a file.
- Clear stale diagnostics when restarting ycmd.
- Keep polling work-done progress that is still displayed after its originating
  buffer or window is closed.
- Avoid clearing document highlights through deleted Neovim buffer handles.

### Tests and continuous integration

- Share editor-independent integration-test behavior between Vim and Neovim
  through thin editor-specific adapters.
- Run completion, completion-info, commands, diagnostics, filesize, FixIt,
  finder, hierarchy, hover, inlay-hint, progress, semantic-highlighting, and
  signature-help integration suites in both editors.
- Run the Neovim integration suite in CI.
- Collect and upload Python and Vimscript coverage from both Vim and Neovim
  integration jobs.
- Exercise documentation generation when the README, generator, or its
  workflow changes.
- Generate Vim help in a Docker container for reproducible documentation.

### Documentation and installation

- Document Neovim as supported and describe its feature-specific version
  requirements.
- Document automatic document highlighting and runtime language-server
  controls.
- Use vim-plug instead of the obsolete Vundle plugin manager in installation
  examples.

## Intentional differences and remaining limitations

- Neovim's finder floating window does not provide Vim's draggable and
  resizable popup behavior or its close button.
- Hierarchy windows retain editor-specific handling for otherwise unmapped
  keys.
- Neovim 0.10 or later is required for the complete feature set, although the
  documented minimum version supports a subset.
