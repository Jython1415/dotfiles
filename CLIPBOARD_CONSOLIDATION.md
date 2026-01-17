# Clipboard Tools Consolidation Plan

## Executive Summary

This dotfiles repository currently contains **14 clipboard-related commands** (5 scripts, 4 supporting tools, 3 shell functions, 1 alias, 1 vim setting) with significant overlap and redundancy. This document outlines a consolidation strategy to reduce this to **8 well-organized tools** while improving cross-platform support and user experience.

## Current State Inventory

### Primary Clipboard Tools (5)
1. **clipmerge** - Alfred clipboard history merger (interactive, Python)
2. **html-clipboard** - HTML get/set via NSPasteboard (Swift, macOS-only)
3. **markdownify-clipboard** - HTML → Markdown converter (Bash)
4. **normalize-clipboard** - HTML normalizer (Bash)
5. **apwd** - Apple-style password generator (Swift, macOS-only)

### Supporting Tools (4)
6. **csvcat** - CSV to TSV extractor (Python, general-purpose)
7. **xlcat** - Excel to TSV extractor (Python, general-purpose)
8. **tagwrap** - XML/HTML tag wrapper (Python, general-purpose)
9. **unescape-markdown** - Markdown cleaner (Bash, general-purpose)

### Shell Utilities (4)
10. **cwd** alias - Copy working directory (`pwd | trim | pbcopy`)
11. **copycsv()** function - Wrapper for csvcat + pbcopy
12. **copyxlsx()** function - Wrapper for xlcat + pbcopy
13. **cliptagwrap()** function - Wrapper for tagwrap with clipboard I/O

### Configuration (1)
14. **.vimrc** - `set clipboard=unnamed` (vim clipboard integration)

## Problem Analysis

### 1. Redundant Shell Function Wrappers
- `copycsv()`, `copyxlsx()`, `cliptagwrap()` are thin wrappers that just add `pbcopy`/`pbpaste`
- Violates DRY principle, maintenance burden

### 2. HTML Pipeline Fragmentation
- `html-clipboard`, `markdownify-clipboard`, `normalize-clipboard` are tightly coupled
- Each is a separate command despite being used together
- Inconsistent error handling and platform support

### 3. macOS Lock-in
- All tools hardcode `pbcopy`/`pbpaste` or use NSPasteboard
- No cross-platform clipboard abstraction
- Incompatible with Linux environments

### 4. Inconsistent Interface Design
- Some tools read/write clipboard directly (markdownify-clipboard)
- Others use stdin/stdout (csvcat, xlcat)
- No consistent naming convention or argument patterns

## Proposed Solution

### New Tool Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   CLIPBOARD LAYER                        │
├─────────────────────────────────────────────────────────┤
│  clip                                                    │
│  ├── get [--format text|html|rtf]                       │
│  ├── set [--format text|html]                           │
│  ├── copy (alias for set)                               │
│  └── paste (alias for get)                              │
│                                                          │
│  Cross-platform: pbcopy/pbpaste | xclip | wl-clipboard  │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │
         ┌────────────────┴────────────────┐
         │                                 │
┌────────┴──────────┐           ┌─────────┴──────────┐
│  TRANSFORM LAYER  │           │   IMPORT LAYER     │
├───────────────────┤           ├────────────────────┤
│  clip-transform   │           │  clip-import       │
│  ├── html-to-md   │           │  ├── csv [FILE]    │
│  ├── normalize    │           │  └── xlsx [FILE]   │
│  └── wrap TAG     │           │                    │
└───────────────────┘           └────────────────────┘
         │                                 │
         │                                 │
         └─────────┬───────────────────────┘
                   │
         ┌─────────┴──────────┐
         │  SUPPORTING TOOLS  │
         ├────────────────────┤
         │  • csvcat          │
         │  • xlcat           │
         │  • tagwrap         │
         │  • unescape-md     │
         └────────────────────┘

┌───────────────────────────────┐
│  SPECIALIZED TOOLS (KEEP)     │
├───────────────────────────────┤
│  • clipmerge (Alfred)         │
│  • apwd (password gen)        │
└───────────────────────────────┘
```

### New Tools Detail

#### 1. `clip` - Cross-Platform Clipboard I/O

**Purpose**: Single abstraction for all clipboard read/write operations

**Implementation**: Python script with platform detection
```python
# Pseudo-implementation
def get_clipboard_command():
    if platform == 'darwin':
        return ('pbcopy', 'pbpaste')
    elif has_command('wl-copy'):
        return ('wl-copy', 'wl-paste')
    elif has_command('xclip'):
        return ('xclip -selection clipboard -in', 'xclip -selection clipboard -out')
    else:
        raise UnsupportedPlatform()
```

**Commands**:
```bash
clip get                  # Get text from clipboard
clip get --format html    # Get HTML from clipboard (macOS NSPasteboard, Linux HTML support)
clip set                  # Read stdin, write to clipboard
clip set --format html    # Read stdin as HTML, write to clipboard
clip copy                 # Alias for 'set'
clip paste                # Alias for 'get'
```

**Replaces**:
- `html-clipboard` (NSPasteboard HTML operations)
- Direct `pbcopy`/`pbpaste` usage in scripts
- Future-proof for Linux support

**Migration**:
```bash
# Before
html-clipboard get
echo "text" | pbcopy

# After
clip get --format html
echo "text" | clip copy
```

---

#### 2. `clip-transform` - Clipboard Transformations

**Purpose**: Atomic clipboard transformations (read → transform → write)

**Implementation**: Bash script wrapping existing utilities
```bash
#!/usr/bin/env bash
case "$1" in
  html-to-md)
    clip get --format html | pandoc -f html -t gfm | unescape-markdown | clip set
    ;;
  normalize-html)
    clip get --format html | pandoc -f html -t gfm | pandoc -f gfm -t html | clip set --format html
    ;;
  wrap)
    shift
    clip get | tagwrap "$@" | clip set
    ;;
esac
```

**Commands**:
```bash
clip-transform html-to-md              # Convert HTML to Markdown in clipboard
clip-transform normalize-html          # Normalize HTML via MD round-trip
clip-transform wrap content            # Wrap clipboard in <content>...</content>
clip-transform wrap div -a class=foo   # Wrap with attributes
```

**Replaces**:
- `markdownify-clipboard`
- `normalize-clipboard`
- `cliptagwrap()` function

**Migration**:
```bash
# Before
markdownify-clipboard
cliptagwrap div -a class=foo

# After
clip-transform html-to-md
clip-transform wrap div -a class=foo
```

---

#### 3. `clip-import` - Import Data to Clipboard

**Purpose**: Import tabular data from files to clipboard

**Implementation**: Bash script wrapping csvcat/xlcat
```bash
#!/usr/bin/env bash
case "$1" in
  csv)
    shift
    csvcat "$@" | clip copy
    ;;
  xlsx)
    shift
    xlcat "$@" | clip copy
    ;;
esac
```

**Commands**:
```bash
clip-import csv                      # Most recent CSV in current dir → clipboard
clip-import csv report.csv           # Specific CSV file → clipboard
clip-import csv -d ~/Downloads       # Most recent in Downloads
clip-import xlsx                     # Most recent Excel file → clipboard
clip-import xlsx -d ~/Downloads --sheet Data
```

**Replaces**:
- `copycsv()` function
- `copyxlsx()` function

**Migration**:
```bash
# Before
copycsv
copyxlsx ~/Downloads

# After
clip-import csv
clip-import xlsx -d ~/Downloads
```

---

### Tools to Keep (No Changes)

#### Specialized Tools
- **clipmerge** - Unique Alfred integration, complex interactive UI
- **apwd** - Security-sensitive, uses concealed pasteboard type

#### General-Purpose Supporting Tools
- **csvcat** - Useful for non-clipboard CSV processing
- **xlcat** - Useful for non-clipboard Excel processing
- **tagwrap** - Useful for non-clipboard XML wrapping
- **unescape-markdown** - Used by clip-transform, useful standalone

#### Configuration
- **.vimrc** `clipboard=unnamed` - Keep (consider upgrading to `unnamedplus` per ROADMAP.md)

### Files to Remove

**Scripts** (3):
- `/home/user/dotfiles/bin/html-clipboard` → replaced by `clip get/set --format html`
- `/home/user/dotfiles/bin/markdownify-clipboard` → replaced by `clip-transform html-to-md`
- `/home/user/dotfiles/bin/normalize-clipboard` → replaced by `clip-transform normalize-html`

**Shell Functions** (3 from `.zshrc`):
- `copycsv()` → replaced by `clip-import csv`
- `copyxlsx()` → replaced by `clip-import xlsx`
- `cliptagwrap()` → replaced by `clip-transform wrap`

**Shell Aliases** (1 from `.zshrc`):
- `cwd='pwd | trim | pbcopy'` → replaced by `pwd | trim | clip copy`

## Implementation Roadmap

### Phase 1: Create Core Infrastructure
1. Implement `clip` tool with cross-platform support
   - macOS: pbcopy/pbpaste + NSPasteboard (for HTML)
   - Linux: xclip or wl-clipboard detection
   - Support text and HTML formats
2. Test on macOS and Linux environments

### Phase 2: Create Transform Layer
1. Implement `clip-transform` with three operations:
   - `html-to-md`
   - `normalize-html`
   - `wrap`
2. Ensure backward-compatible behavior with old tools
3. Add tests for each transformation

### Phase 3: Create Import Layer
1. Implement `clip-import` wrapping csvcat/xlcat
2. Test auto-detection of recent files
3. Verify all csvcat/xlcat options work through wrapper

### Phase 4: Migration
1. Update any scripts/workflows using old tools to use new ones
2. Remove deprecated scripts:
   - `rm bin/html-clipboard`
   - `rm bin/markdownify-clipboard`
   - `rm bin/normalize-clipboard`
3. Update `.zshrc`:
   - Remove `copycsv()` function
   - Remove `copyxlsx()` function
   - Remove `cliptagwrap()` function
   - Remove `cwd` alias (or update to `alias cwd='pwd | trim | clip copy'`)

### Phase 5: Documentation
1. Update README.md with new clipboard tool documentation
2. Add usage examples for each new tool
3. Create migration guide for old commands

## Before/After Comparison

### Tool Count
- **Before**: 14 clipboard-related items (5 scripts + 4 supporting + 3 functions + 1 alias + 1 config)
- **After**: 8 items (3 new scripts + 2 specialized + 3 supporting + 1 config)
- **Reduction**: 43% fewer items to maintain

### Common Workflows

#### Convert HTML to Markdown
```bash
# Before
markdownify-clipboard

# After
clip-transform html-to-md
```

#### Copy Excel to Clipboard
```bash
# Before
copyxlsx ~/Downloads

# After
clip-import xlsx -d ~/Downloads
```

#### HTML Clipboard Operations
```bash
# Before
html-clipboard get
html-clipboard set

# After
clip get --format html
clip set --format html
```

#### Copy Current Directory
```bash
# Before
cwd

# After
pwd | trim | clip copy
```

## Benefits Summary

### 1. Reduced Complexity
- 3 fewer scripts to maintain
- 3 fewer shell functions
- Clearer separation of concerns

### 2. Improved Consistency
- All clipboard I/O through single `clip` abstraction
- Consistent naming: `clip-*` prefix for all clipboard-specific tools
- Uniform argument patterns

### 3. Cross-Platform Support
- `clip` tool abstracts platform differences
- Linux support out of the box
- Easy to add new platform support in one place

### 4. Better Discoverability
- Related operations grouped under namespaces
- `clip-transform` groups all transformations
- `clip-import` groups all imports
- Easy to list with tab completion: `clip-<TAB>`

### 5. Backward Compatibility
- Keep `csvcat`, `xlcat`, `tagwrap` for non-clipboard uses
- Can add aliases for old commands during transition
- No breaking changes to general-purpose tools

### 6. Unix Philosophy Maintained
- Tools still composable via stdin/stdout
- Each tool does one thing well
- Can still use `clip get | other-tool | clip set` pattern

## Migration Cheat Sheet

| Old Command | New Command |
|-------------|-------------|
| `html-clipboard get` | `clip get --format html` |
| `html-clipboard set` | `clip set --format html` |
| `markdownify-clipboard` | `clip-transform html-to-md` |
| `normalize-clipboard` | `clip-transform normalize-html` |
| `copycsv` | `clip-import csv` |
| `copyxlsx` | `clip-import xlsx` |
| `cliptagwrap div` | `clip-transform wrap div` |
| `echo "text" \| pbcopy` | `echo "text" \| clip copy` |
| `pbpaste` | `clip paste` |
| `cwd` | `pwd \| trim \| clip copy` |

## Open Questions

1. **Transition Strategy**: Should we keep old tools as deprecated wrappers temporarily?
2. **Naming**: Is `clip-transform` vs `clip-convert` better?
3. **HTML Support on Linux**: How to handle HTML clipboard on Linux? (might need python + gi.repository.Gdk)
4. **Vim Integration**: Should `clip` tool integrate with vim's clipboard setting?

## Success Criteria

- [ ] All old clipboard workflows work with new tools
- [ ] `clip` tool works on macOS and Linux
- [ ] `clip` tool supports text and HTML formats
- [ ] All transformation operations produce identical output to old tools
- [ ] Documentation updated with new commands
- [ ] Migration guide created
- [ ] Old scripts removed from repository
- [ ] Shell functions removed from `.zshrc`
- [ ] No regression in functionality
- [ ] Improved discoverability (can list all clipboard tools with `clip*` glob)
