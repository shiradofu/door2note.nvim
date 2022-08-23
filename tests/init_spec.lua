local Job = require 'plenary.job'
local script_dir = debug.getinfo(1).source:match '@?(.*/)'
local assets_dir = vim.loop.fs_realpath(script_dir .. '/assets')
local note_dir = vim.loop.fs_realpath(assets_dir .. '/notes')
local proj_dir = vim.loop.fs_realpath(assets_dir .. '/projects/proj-a')
assert(note_dir, 'note_dir must be exist')
assert(proj_dir, 'proj_dir must be exist')
Job:new({ command = 'git', args = { 'init' }, cwd = proj_dir }):sync()
vim.loop.cwd = function() return proj_dir .. '/inside' end

local door2note = require 'door2note'
local util = require 'door2note.util'
local _stub = require 'luassert.stub'
local _spy = require 'luassert.spy'
local match = require 'luassert.match'

local default_config = vim.deepcopy(door2note.config)
local function reset_config() door2note.config = vim.deepcopy(default_config) end
local mocks = {}
local function mock(is_stub, ...)
  local s = is_stub and _stub(...) or _spy.on(...)
  table.insert(mocks, s)
  return s
end
local function revert_mocks()
  for _, fn in ipairs(mocks) do
    fn:revert()
  end
  mocks = {}
end
local function reset_wins()
  vim.cmd 'silent! %bdelete'
  local wins = vim.api.nvim_list_wins()
  for i = #wins, 2, -1 do
    vim.api.nvim_win_close(wins[i], true)
  end
  vim.api.nvim_win_set_width(0, vim.go.columns)
  vim.api.nvim_win_set_height(0, vim.go.lines)
end

describe('door2note', function()
  before_each(function()
    revert_mocks()
    reset_wins()
    reset_config()
  end)

  describe('setup', function()
    it('should fail if note_dir is not a directory', function()
      local err = mock(true, util, 'err')
      local ok = door2note.setup { note_dir = '/invalid/directory' }
      assert.Nil(ok)
      assert.stub(err).called_with(match.has_match 'directory', match._)
    end)

    it(
      'should fail if refresh.nvim is not installed despite integration enabled',
      function()
        local loaders = vim.deepcopy(package.loaders)
        package.loaders = { loaders[1] }
        local err = mock(true, util, 'err')
        local ok = door2note.setup {
          note_dir = note_dir,
          integrations = { refresh = { enabled = true } },
        }
        assert.Nil(ok)
        assert.stub(err).called_with(match.has_match 'refresh')
        package.loaders = loaders
      end
    )

    it('should set on_enter hook', function()
      local spy = _spy.new()
      door2note.setup {
        note_dir = note_dir,
        hooks = { on_enter = function() spy() end },
      }
      vim.cmd('e ' .. note_dir .. '/proj-a.md')
      assert.spy(spy).called(1)
    end)

    it('should set on_leave hook', function()
      local spy = _spy.new()
      door2note.setup {
        note_dir = note_dir,
        hooks = { on_leave = function() spy() end },
      }
      vim.cmd('e ' .. note_dir .. '/proj-a.md | enew')
      assert.spy(spy).called(1)
    end)
  end)

  describe('_find_or_create_buf', function()
    it('should return existing buf', function()
      vim.cmd('e ' .. note_dir .. '/proj-a.md | enew')
      local bufnr = vim.api.nvim_get_current_buf()
      vim.b[bufnr][door2note.id_tag()] = true
      local note_path = mock(true, door2note.config, 'note_path')

      assert.equals(bufnr, door2note._find_or_create_buf())
      assert.stub(note_path).called(0)
    end)

    it('should fail if project_root not found', function()
      local err = mock(true, util, 'err')
      door2note.setup { note_dir = note_dir, root_patterns = {} }
      local bufnr = door2note._find_or_create_buf()

      assert.Nil(bufnr)
      assert.stub(err).called_with(match.has_match 'root')
    end)

    it('should fail if note_path returns empty', function()
      local err = mock(true, util, 'err')
      door2note.setup { note_dir = note_dir }
      local bufnr = door2note._find_or_create_buf()

      assert.Nil(bufnr)
      assert.stub(err).called_with(match.has_match 'note_path')
    end)

    it('should fail if note_dir is not a directory', function()
      local tmp_dir = assets_dir .. '/tmp'
      Job:new({ command = 'mkdir', args = { tmp_dir } }):sync()
      door2note.setup {
        note_dir = tmp_dir,
        note_path = function() return 'any' end,
      }
      Job:new({ command = 'rmdir', args = { tmp_dir } }):sync()
      local err = mock(true, util, 'err')

      local bufnr = door2note._find_or_create_buf()

      assert.Nil(bufnr)
      assert.stub(err).called_with(match.has_match 'directory', match._)
    end)

    it('should create new note file if not exists', function()
      door2note.setup {
        note_dir = note_dir,
        note_path = function() return 'note.md' end,
      }
      local job = mock(false, Job, 'new')

      local bufnr = door2note._find_or_create_buf()

      assert.Number(bufnr)
      assert.True(vim.b[bufnr][door2note.id_tag()])
      assert.spy(job).called(2)
      assert.equals(1, vim.fn.filereadable(note_dir .. '/note.md'))
      Job:new({ command = 'rm', args = { note_dir .. '/note.md' } }):sync()
    end)

    it('should find existing note', function()
      door2note.setup {
        note_dir = note_dir,
        note_path = function(proj_root)
          -- should return 'proj-a.md'
          return proj_root:sub(proj_root:find '[^/]+$') .. '.md'
        end,
      }
      local job = mock(true, Job, 'new')

      local bufnr = door2note._find_or_create_buf()

      assert.Number(bufnr)
      assert.True(vim.b[bufnr][door2note.id_tag()])
      assert.spy(job).called(0)
    end)
  end)

  local function base_config(config)
    return vim.tbl_deep_extend('force', {
      note_dir = note_dir,
      note_path = function() return 'proj-a.md' end,
    }, config or {})
  end

  describe('open_normal', function()
    describe('should set height correctly', function()
      vim.go.lines = 50
      vim.api.nvim_win_set_height(0, vim.go.lines)
      local max = vim.api.nvim_win_get_height(0) - 2
      for _, val in ipairs {
        { 10, 10 },
        { 0.8, 40 },
        { max + 100, max },
        { nil, max },
      } do
        local config, expected = unpack(val)
        local name = config == max + 100 and 'max + 100' or config
        it(('{ height = %s }'):format(name), function()
          door2note.setup(base_config())
          door2note.config.normal_window.open_cmd = 'new'
          door2note.config.normal_window.height = config
          door2note.open_normal()

          assert.equals(expected, vim.api.nvim_win_get_height(0))
        end)
      end
    end)

    describe('should set width correctly', function()
      vim.go.columns = 200
      vim.api.nvim_win_set_width(0, vim.go.columns)
      local max = vim.api.nvim_win_get_width(0) - 2
      for _, val in ipairs {
        { 100, 100 },
        { 0.5, 100 },
        { max + 100, max },
        { nil, max },
      } do
        local config, result = unpack(val)
        local name = config == max + 100 and 'max + 100' or config
        it(('{ width = %s }'):format(name), function()
          door2note.setup(base_config())
          door2note.config.normal_window.open_cmd = 'vnew'
          door2note.config.normal_window.width = config
          door2note.open_normal()

          assert.equals(result, vim.api.nvim_win_get_width(0))
        end)
      end
    end)

    it('should focus existing win', function()
      door2note.setup(base_config())
      door2note.open_normal()
      local focus = mock(false, vim.api, 'nvim_set_current_win')
      local find_buf = mock(true, door2note, '_find_or_create_buf')
      vim.cmd 'wincmd w'

      door2note.open_normal()

      assert.True(vim.b[door2note.id_tag()])
      assert.spy(focus).called(1)
      assert.stub(find_buf).called(0)
    end)
  end)

  describe('open_float', function()
    describe('should set height correctly', function()
      vim.go.lines = 50
      vim.api.nvim_win_set_height(0, vim.go.lines)
      local max = vim.api.nvim_win_get_height(0) + 1
      for _, val in ipairs {
        { 10, 10 },
        { 0.8, 40 },
        { max + 100, max },
        { nil, max },
      } do
        local config, expected = unpack(val)
        local name = config == max + 100 and 'max + 100' or config
        it(('{ height = %s }'):format(name), function()
          door2note.setup(base_config())
          door2note.config.float_window.open_cmd = 'new'
          door2note.config.float_window.height = config
          door2note.open_float()

          assert.equals(expected, vim.api.nvim_win_get_height(0))
        end)
      end
    end)

    describe('should set width correctly', function()
      vim.go.columns = 200
      vim.api.nvim_win_set_width(0, vim.go.columns)
      local max = vim.api.nvim_win_get_width(0)
      for _, val in ipairs {
        { 100, 100 },
        { 0.5, 100 },
        { max + 100, max },
        { nil, max },
      } do
        local config, expected = unpack(val)
        local name = config == max + 100 and 'max + 100' or config
        it(('{ width = %s }'):format(name), function()
          door2note.setup(base_config())
          door2note.config.float_window.open_cmd = 'vnew'
          door2note.config.float_window.width = config
          door2note.open_float()

          assert.equals(expected, vim.api.nvim_win_get_width(0))
        end)
      end
    end)
  end)

  describe('open', function()
    for _, scope in ipairs { 'b', 'w', 'g' } do
      it('should use door2note_open_fn (scope=' .. scope .. ')', function()
        door2note.setup(base_config())
        local fn_name = 'open_float'
        local fn = mock(true, door2note, fn_name)
        vim[scope].door2note_open_fn = fn_name

        door2note.open()

        assert.stub(fn).called(1)
      end)
    end
  end)
end)

revert_mocks()
Job:new({ command = 'rm', args = { '-rf', proj_dir .. '/.git' } }):sync()
