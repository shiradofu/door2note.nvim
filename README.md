<p align="center">
  <h1 align="center">🚪door2note.nvim</h1>
</p>

Note: still on alpha stage, public APIs might be changed.

## 📐 Motivation

I like taking notes while I'm writing codes to organize my thoughts. Of course
I'm using neovim for developing, I also want to take a project-related note
inside this paradise.

We can do so with...

- Making a git-ignored file inside the project directory
  - It works, but we cannot see it on other machines.
- Creating a repository only for our notes
  - Good, but it's a drag to open the note file when we're in the project
    directory.

This plugin improves the second approach, allowing us to open a related note
with one command.

But there's still a problem. We have to add, commit, and push the changes
manually. If (and probably often) we forget it, we end up with hitting the
bottle :(

So, this plugin has an integration with
[refresh.nvim](https://github.com/shiradofu/refresh.nvim), which provides auto
pull and push features!

It's perfect, isn't it? :D

## 🛠 Installation

**requirements**

- neovim 0.7+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

with [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'shiradofu/door2note.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'shiradofu/refresh.nvim',
  },
  config = function()
    require('door2note').setup {
      -- setup here...
    }
  end,
}
```

## 🔩 Configuration

**path config**

Suppose you are in `$HOME/workspace/my/project` directory.  
With the following settings, you'll have `$HOME/workspace/notes/my-project.md`.

```lua
require('door2note').setup {
  -- Directory containing notes.
  note_dir = vim.env.HOME .. '/workspace/notes',

  -- Patterns to find project root. Lua patterns are accepted.
  -- This is a default value.
  root_patterns = { '/%.git$' },

  -- Function making a note path from a project root path.
  -- Returned path has to be relative to `note_dir`.
  -- If returns nil or empty string, no file would be opened.
  note_path = function(project_root)
    local workspace = vim.env.HOME .. '/workspace/'
    if vim.startswith(project_root, workspace) then
      return root:sub(#workspace):gsub('/', '-') .. '.md'
    end
  end,
}

```

**The other configs**

These are the default values.

```lua
require('door2note').setup {
  normal_window = {
    -- Vim command used when opening a normal window.
    open_cmd = 'topleft new',

    -- You can specify width and height of the opened window.
    -- Positive numbers are accepted.
    -- N < 1:  N is considered as ratio.
    -- N >= 1: N is considered as fixed lines/columns size.
    --         In this case, N has to be an integer.
    height = 0.33,
    -- width = 80,
  },

  float_window = {
    -- Spec of width/height is the same as config.window.
    -- zindex and border is directly passed to nvim_open_win().
    width = 0.8,
    height = 0.8,
    zindex = 50,
    border = 'double',
  },

  -- Hooks which run on `BufEnter`/`BufLeave`.
  -- You can set buffer local keymaps or something here.
  hooks = {
    on_enter = function() end,
    on_leave = function() end,
  },

  integrations = {
    -- refresh.nvim integration.
    -- See docs of refresh.nvim for details.
    -- https://github.com/shiradofu/refresh.nvim/#-usage
    refresh = {
      enabled = false,
      pull = { silent = false },
      delete_empty = { files = 'SESSION' },
      push = { files = 'SESSION' },
      branch = nil,
    },
  },
}
```

## 🔑 Usage

Lua functions:

```lua
local door2note = require('door2note')

door2note.open_normal()
door2note.open_float()
door2note.open()
```

Vim commands:

```vim
:Door2NoteOpenNormal
:Door2NoteOpenFloat
:Door2NoteOpen
```

Open a note file according to `config.note_dir` and `config.note_path`. If there
is already a window that shows the note in the current tab, simply focus on it.

`open()` decides window type depending on `vim.b.door2note_open_fn`,
`vim.w.door2note_open_fn` or `vim.g.door2note_open_fn`. Its default value is
`open_normal`.
