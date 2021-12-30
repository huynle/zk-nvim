local lsp = require("zk.lsp")
local config = require("zk.config")
local ui = require("zk.ui")
local api = require("zk.api")
local util = require("zk.util")

local M = {}

local function setup_lsp_auto_attach()
  --- NOTE: modified version of code in nvim-lspconfig
  local trigger
  local filetypes = config.options.lsp.auto_attach.filetypes
  if filetypes then
    trigger = "FileType " .. table.concat(filetypes, ",")
  else
    trigger = "BufReadPost *"
  end
  vim.api.nvim_command(string.format("autocmd %s lua require'zk'._lsp_buf_auto_add(0)", trigger))
end

---Automatically called via an |autocmd| if lsp.auto_attach is enabled.
--
---@param bufnr number
function M._lsp_buf_auto_add(bufnr)
  if vim.api.nvim_buf_get_option(bufnr, "buftype") == "nofile" then
    return
  end

  if not util.notebook_root(vim.api.nvim_buf_get_name(bufnr)) then
    return
  end

  lsp.buf_add(bufnr)
end

---The entry point of the plugin
--
---@param options? table user configuration options
function M.setup(options)
  config.options = vim.tbl_deep_extend("force", config.defaults, options or {})

  if config.options.lsp.auto_attach.enabled then
    setup_lsp_auto_attach()
  end

  require("zk.commands.builtin")
end

function M.cd(options)
  options = options or {}
  local notebook_path = options.notebook_path or util.resolve_notebook_path(0)
  local root = util.notebook_root(notebook_path)
  if root then
    vim.cmd("cd " .. root)
  end
end

function M.new(options)
  options = options or {}
  api.new(options.notebook_path, options, function(res)
    if options and options.edit == false then
      return
    end
    -- neovim does not yet support window/showDocument, therefore we handle options.edit locally
    vim.cmd("edit " .. res.path)
  end)
end

function M.index(options)
  options = options or {}
  api.index(options.notebook_path, options, function(stats)
    vim.notify(vim.inspect(stats))
  end)
end

function M.pick_notes(options, picker_options, cb)
  options = vim.tbl_extend(
    "force",
    { select = ui.get_pick_notes_list_api_selection(picker_options), sort = { "created" } },
    options or {}
  )
  api.list(options.notebook_path, options, function(notes)
    ui.pick_notes(notes, picker_options, cb)
  end)
end

function M.pick_tags(options, picker_options, cb)
  options = vim.tbl_extend("force", { sort = { "note-count" } }, options or {})
  api.tag.list(options.notebook_path, options, function(tags)
    ui.pick_tags(tags, picker_options, cb)
  end)
end

function M.edit(options, picker_options)
  M.pick_notes(options, picker_options, function(notes)
    if picker_options.multi_select == false then
      notes = { notes }
    end
    for _, note in ipairs(notes) do
      vim.cmd("e " .. note.absPath)
    end
  end)
end

function M.edit_from_tags(options, picker_options)
  M.pick_tags(options, picker_options, function(tags)
    tags = vim.tbl_map(function(v)
      return v.name
    end, tags)
    M.edit({ tags = tags }, { title = "Zk Notes for tag(s) " .. vim.inspect(tags) })
  end)
end

return M
