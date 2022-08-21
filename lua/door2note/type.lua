---@alias FloatWindowBorder 'none'|'single'|'double'|'rounded'|'solid'|'shadow'|string[]

---@class Door2Note.Config.NormalWindow
---@field open_cmd string
---@field width number
---@field height number

---@class Door2Note.Config.FloatWindow
---@field width number
---@field height number
---@field zindex number
---@field border FloatWindowBorder

---@class Door2Note.Config.Hooks
---@field on_enter fun():nil
---@field on_leave fun():nil

---@class Door2Note.Config.Integrations
---@field refresh Door2Note.Config.Integrations.Refresh

---@class Door2Note.Config.Integrations.Refresh
---@field enabled boolean
---@field pull table
---@field delete_empty table
---@field push table
---@field branch? string

---@class Door2Note.Config
---@field note_dir string
---@field root_patterns string|string[]
---@field note_path fun(root_path: string): string|nil
---@field normal_window Door2Note.Config.NormalWindow
---@field float_window Door2Note.Config.FloatWindow
---@field hooks Door2Note.Config.Hooks
---@field integrations Door2Note.Config.Integrations
