require 'door2note.type'
local util = require 'door2note.util'
local Job = require 'plenary.job'
local scan_dir = require('plenary.scandir').scan_dir

---@class Door2Note
---@field config Door2Note.Config
local M = {}

local id_tag = 'is_door2note_target'
function M.id_tag() return id_tag end

M.config = {
  note_dir = '',
  root_patterns = { '/%.git$' },
  note_path = function(proj_root) util.err 'Please set `note_path` function.' end,
  normal_window = {
    open_cmd = 'topleft new',
    height = 0.33,
  },
  float_window = {
    width = 0.8,
    height = 0.8,
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

---@param config Door2Note.Config
---@return Door2Note.Config|nil
function M.setup(config)
  M.config = vim.tbl_deep_extend('force', M.config, config)
  if vim.fn.isdirectory(M.config.note_dir) == 0 then
    util.err("config.note_dir '%s' is not a directory.", M.config.note_dir)
    return
  end
  M.config.note_dir = vim.endswith(M.config.note_dir, '/') and M.config.note_dir
    or M.config.note_dir .. '/'

  if M.config.integrations.refresh.enabled then
    local ok, refresh = pcall(require, 'refresh')
    if not ok then
      util.err 'refresh.nvim is not installed.'
      return
    end
    refresh.register(M.config.note_dir, M.config.integrations.refresh)
  end

  local augroup = vim.api.nvim_create_augroup('Door2Note', {})
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    pattern = M.config.note_dir .. '*',
    callback = M.config.hooks.on_enter,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = augroup,
    pattern = M.config.note_dir .. '*',
    callback = M.config.hooks.on_leave,
  })

  return M.config
end

---if a window in the current tab shows a note, focus on it.
---@return boolean
local function focus_win_if_exists()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.b[vim.api.nvim_win_get_buf(winid)][id_tag] then
      vim.api.nvim_set_current_win(winid)
      return true
    end
  end
  return false
end

---@param patterns string|string[]
---@param start string|nil
---@return string|nil
local function find_root(patterns, start)
  start = start or vim.loop.cwd()
  if start == '/' then return nil end
  for _, p in ipairs(patterns) do
    local found = scan_dir(start, {
      search_pattern = p,
      hidden = true,
      add_dirs = true,
      depth = 1,
    })
    if #found > 0 then return start end
  end
  return find_root(patterns, vim.loop.fs_realpath(start .. '/../'))
end

---@param cmd string
---@param ... any args
---@return boolean is_succeeded
local function job_sync(cmd, ...)
  local _, code = Job:new({ command = cmd, args = { ... } }):sync()
  return code == 0
end

---@return number|nil
function M._find_or_create_buf()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.b[bufnr][id_tag] then
      return bufnr
    end
  end

  local project_root = find_root(M.config.root_patterns)
  if not project_root then
    util.err 'Project root not found.'
    return
  end
  local note_path = M.config.note_path(project_root)
  if not note_path or note_path == '' then
    util.err 'config.note_path() returned empty.'
    return
  end
  if vim.fn.isdirectory(M.config.note_dir) == 0 then
    util.err("config.note_dir '%s' is not a directory.", M.config.note_dir)
    return
  end
  local note_fullpath = M.config.note_dir .. note_path
  if vim.fn.filereadable(note_fullpath) == 0 then
    local ok = job_sync('mkdir', '-p', note_fullpath:gsub('/[^/]+/?$', ''))
    if ok then ok = job_sync('touch', note_fullpath) end
    if not ok then
      util.err("Failed to create a new file '%s'", note_fullpath)
      return
    end
  end
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_call(bufnr, function() vim.cmd('edit ' .. note_fullpath) end)
  vim.b[bufnr][id_tag] = true
  return bufnr
end

---@param config Door2Note.Config.NormalWindow|Door2Note.Config.FloatWindow
---@return number width
---@return number height
local function calc_win_size(config)
  local result = {}
  for _, d in ipairs { 'width', 'height' } do
    local max = d == 'width' and vim.go.columns or vim.go.lines
    -- print(max)
    local val = config[d] or max
    result[d] = math.min((val >= 1 and val or math.floor(max * val)), max)
  end
  return result.width, result.height
end

function M.open_normal()
  if focus_win_if_exists() then return end
  local bufnr = M._find_or_create_buf()
  if not bufnr then return end
  local config = M.config.normal_window
  vim.cmd(config.open_cmd)
  local w, h = calc_win_size(config)
  vim.api.nvim_win_set_width(0, w)
  vim.api.nvim_win_set_height(0, h)
  vim.api.nvim_win_set_buf(0, bufnr)
end

function M.open_float()
  if focus_win_if_exists() then return end
  local bufnr = M._find_or_create_buf()
  if not bufnr then return end
  local config = M.config.float_window
  local w, h = calc_win_size(config)
  vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = w,
    height = h,
    col = (vim.go.columns - w) / 2,
    row = (vim.go.lines - h) / 2 - 1,
    focusable = true,
    zindex = config.zindex,
    border = config.border,
  })
end

function M.open()
  local open_fn = vim.b.door2note_open_fn
    or vim.w.door2note_open_fn
    or vim.g.door2note_open_fn
    or 'open_normal'
  M[open_fn]()
end

return M
