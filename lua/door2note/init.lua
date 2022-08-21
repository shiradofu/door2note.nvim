require 'door2note.type'
local util = require 'door2note.util'
local Job = require 'plenary.job'
local scan_dir = require('plenary.scandir').scan_dir

local IS_DOOR2NOTE_TARGET = 'is_door2note_target'

---@class Door2Note
---@field config Door2Note.Config
local M = {}

M.config = {
  note_dir = '',
  root_patterns = { '/%.git$' },
  note_path = function(project_root) util.err 'Please set `note_path` function.' end,
  normal_window = {
    open_cmd = 'topleft new',
    height = 0.33,
  },
  float_window = {
    height = 0.8,
    width = 0.8,
    zindex = 50,
    border = 'double',
  },
  hooks = {
    on_enter = function() end,
    on_leave = function() end,
  },
  integrations = {
    refresh = {
      enabled = false,
      pull = { silent = false },
      delete_empty = { files = 'SESSION' },
      push = { files = 'SESSION' },
      branch = nil,
    },
  },
}

---@param patterns string|string[]
---@param start string|nil
---@return string|nil
local function find_root(patterns, start)
  start = start or vim.loop.cwd()
  if start == '/' then return nil end
  for _, p in ipairs(patterns) do
    local found = scan_dir(
      start,
      { search_pattern = p, hidden = true, add_dirs = true, depth = 1 }
    )
    if #found > 0 then return start end
  end
  return find_root(patterns, vim.loop.fs_realpath(start .. '/../'))
end

---@param cmd string
---@param ... any args
---@return boolean is_succeeded
local function job_sync(cmd, ...)
  local _, code = Job:new({ command = cmd[1], args = { ... } }):sync()
  return code == 0
end

---@return 'open_normal'|'open_float'
local function get_open_fn()
  return vim.b.door2note_open_fn
    or vim.w.door2note_open_fn
    or vim.g.door2note_open_fn
    or 'open_normal'
end

---@param config Door2Note.Config
function M.setup(config)
  M.config = vim.tbl_deep_extend('force', M.config, config)
  local c = M.config

  if vim.fn.isdirectory(c.note_dir) == 0 then
    util.err("config.note_dir '%s' is not a directory.", M.config.note_dir)
    return false
  end

  if c.integrations.refresh.enabled then
    local ok, refresh = pcall(require, 'refresh')
    if not ok then
      util.err 'refresh.nvim is not installed.'
      return false
    end
    refresh.register(c.note_dir, c.integrations.refresh)
  end

  local augroup = vim.api.nvim_create_augroup('Door2Note', {})
  local note_dir_pattern = (
    vim.endswith(c.note_dir, '/') and c.note_dir or c.note_dir .. '/'
  ) .. '*'
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    pattern = note_dir_pattern,
    callback = c.hooks.on_enter,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = augroup,
    pattern = note_dir_pattern,
    callback = c.hooks.on_leave,
  })
end

---@return boolean is_succeeded
function M.open()
  -- if a window in the current tab shows door2note, focus on it.
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.b[vim.api.nvim_win_get_buf(winid)][IS_DOOR2NOTE_TARGET] then
      vim.api.nvim_set_current_win(winid)
      return true
    end
  end

  -- If there's a loaded door2note buffer, exec open_cmd and set the buffer there.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(bufnr) and vim.b[bufnr][IS_DOOR2NOTE_TARGET]
    then
      M[get_open_fn()](bufnr)
      return true
    end
  end

  local project_root = find_root(M.config.root_patterns)
  if not project_root then
    util.err 'Project root not found.'
    return false
  end
  local note_path = M.config.note_path(project_root)
  if not note_path or note_path == '' then
    util.err 'config.note_path() returned empty.'
    return false
  end
  local note_fullpath = util.path_join(M.config.note_dir, note_path)
  if vim.fn.filereadable(note_fullpath) == 0 then
    local ok = job_sync('mkdir', '-p', note_fullpath:gsub('/[^/]+/?$', ''))
    if ok then ok = job_sync('touch', note_fullpath) end
    if not ok then
      util.err("Failed to create a new file '%s'", note_fullpath)
      return false
    end
  end
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_call(bufnr, function() vim.cmd('edit ' .. note_fullpath) end)
  M[get_open_fn()](bufnr)
  vim.b[bufnr][IS_DOOR2NOTE_TARGET] = true
  return true
end

---@param d 'width'|'height'
---@param config Door2Note.Config.NormalWindow|Door2Note.Config.FloatWindow
local function win_size(d, config)
  local max = d == 'height' and vim.go.lines or vim.go.columns
  local val = config[d]
  if not val then return nil end
  return val >= 1 and val or math.floor(max * val)
end

---@return boolean is_succeeded
function M.open_normal(bufnr)
  local config = M.config.normal_window
  vim.cmd(config.open_cmd)
  local width = win_size('width', config)
  if width then vim.api.nvim_win_set_width(0, width) end
  local height = win_size('height', config)
  if height then vim.api.nvim_win_set_height(0, height) end
  vim.api.nvim_win_set_buf(0, bufnr)
  return true
end

---@return boolean is_succeeded
function M.open_float(bufnr)
  local config = M.config.float_window
  local width = win_size('width', config)
  local height = win_size('height', config)
  vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.go.columns - width) / 2,
    row = (vim.go.lines - height) / 2 - 1,
    focusable = true,
    zindex = config.zindex,
    border = config.border,
  })
  return true
end

return M
