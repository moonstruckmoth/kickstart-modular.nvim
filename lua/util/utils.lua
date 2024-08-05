local Path = require("plenary.path")
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local os_sep = Path.path.sep
local pickers = require("telescope.pickers")
local scan = require("plenary.scandir")
local sorters = require("telescope.sorters")
local utils = require("telescope.utils")
local previewers = require("telescope.previewers")

local M = {}

-- Riesling-Schorle, https://pastebin.com/rB9ZiAFh
M.live_grep_in_folder = function(opts)
  opts = opts or {}
  local data = {}
  scan.scan_dir(vim.fn.expand(vim.fn.input("Dir  ", "", "dir")), {
    hidden = opts.hidden,
    only_dirs = true,
    respect_gitignore = opts.respect_gitignore,
    on_insert = function(entry)
      table.insert(data, entry .. os_sep)
    end,
  })
  table.insert(data, 1, "." .. os_sep)

  pickers
    .new(opts, {
      prompt_title = "Folders for Live Grep",
      finder = finders.new_table({ results = data, entry_maker = make_entry.gen_from_file(opts) }),
      previewer = conf.file_previewer(opts),
      sorter = conf.file_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        action_set.select:replace(function()
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          local dirs = {}
          local selections = current_picker:get_multi_selection()
          if vim.tbl_isempty(selections) then
            table.insert(dirs, action_state.get_selected_entry().value)
          else
            for _, selection in ipairs(selections) do
              table.insert(dirs, selection.value)
            end
          end
          actions._close(prompt_bufnr, current_picker.initial_mode == "insert")
          require("telescope.builtin").live_grep({ prompt_title = "Live grep in folder", search_dirs = dirs })
        end)
        return true
      end,
    })
    :find()
end

M.find_files_in_folder = function()
  require("telescope.builtin").find_files({
    prompt_title = "Find files in folder",
    cwd = vim.fn.expand(vim.fn.input("Dir  ", "", "dir")),
  })
end

M.live_grep_git_files = function(opts)
  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  local search_dirs = opts.search_dirs
  local grep_open_files = opts.grep_open_files
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local flatten = vim.tbl_flatten

  local opts_contain_invert = function(args)
    local invert = false
    local files_with_matches = false

    for _, v in ipairs(args) do
      if v == "--invert-match" then
        invert = true
      elseif v == "--files-with-matches" or v == "--files-without-match" then
        files_with_matches = true
      end

      if #v >= 2 and v:sub(1, 1) == "-" and v:sub(2, 2) ~= "-" then
        local non_option = false
        for i = 2, #v do
          local vi = v:sub(i, i)
          if vi == "=" then -- ignore option -g=xxx
            break
          elseif vi == "g" or vi == "f" or vi == "m" or vi == "e" or vi == "r" or vi == "t" or vi == "T" then
            non_option = true
          elseif non_option == false and vi == "v" then
            invert = true
          elseif non_option == false and vi == "l" then
            files_with_matches = true
          end
        end
      end
    end
    return invert, files_with_matches
  end

  local git_files = function()
    local git_command = vim.F.if_nil(opts.git_command, { "git", "ls-files", "--exclude-standard", "--cached" })
    local results = utils.get_os_command_output(git_command)
    return results
  end

  local filelist = git_files
  if search_dirs then
    for i, path in ipairs(search_dirs) do
      search_dirs[i] = vim.fn.expand(path)
    end
  end

  local additional_args = {}
  if opts.additional_args ~= nil then
    if type(opts.additional_args) == "function" then
      additional_args = opts.additional_args(opts)
    elseif type(opts.additional_args) == "table" then
      additional_args = opts.additional_args
    end
  end

  if opts.type_filter then
    additional_args[#additional_args + 1] = "--type=" .. opts.type_filter
  end

  if type(opts.glob_pattern) == "string" then
    additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern
  elseif type(opts.glob_pattern) == "table" then
    for i = 1, #opts.glob_pattern do
      additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern[i]
    end
  end

  local args = flatten({ vimgrep_arguments, additional_args })
  opts.__inverted, opts.__matches = opts_contain_invert(args)

  local live_grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    local search_list = {}

    if grep_open_files then
      search_list = filelist
    elseif search_dirs then
      search_list = search_dirs
    end

    return flatten({ args, "--", prompt, search_list })
  end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd)

  pickers
    .new(opts, {
      prompt_title = "Live Grep",
      finder = live_grepper,
      previewer = conf.grep_previewer(opts),
      -- TODO: It would be cool to use `--json` output for this
      -- and then we could get the highlight positions directly.
      sorter = sorters.highlighter_only(opts),
      attach_mappings = function(_, map)
        map("i", "<c-space>", actions.to_fuzzy_refine)
        return true
      end,
    })
    :find()
end

M.changed_on_branch = function()
  pickers
    .new({
      prompt_title = "Git files modified in current directory",
      results_title = "Git files modified in current directory",
      finder = finders.new_oneshot_job({
        "git",
        "diff",
        "--name-only",
        "--diff-filter=ACMR",
        "--relative",
        "HEAD",
      }),
      sorter = sorters.get_fuzzy_file(),
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          return {
            "git",
            "-c",
            "core.pager=delta",
            "-c",
            "delta.side-by-side=false",
            "diff",
            "--diff-filter=ACMR",
            "--relative",
            "HEAD",
            "--",
            entry.value,
          }
        end,
      }),
    })
    :find()
end

M.changed_on_root = function()
  local rel_path = string.gsub(vim.fn.system("git rev-parse --show-cdup"), "^%s*(.-)%s*$", "%1")
  if vim.v.shell_error ~= 0 then
    return
  end
  pickers
    .new({
      prompt_title = "Git files modified in current branch",
      results_title = "Git files modified in current branch",
      finder = finders.new_oneshot_job({
        "git",
        "diff",
        "--name-only",
        "HEAD",
      }),
      sorter = sorters.get_fuzzy_file(),
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          return {
            "git",
            "-c",
            "core.pager=delta",
            "-c",
            "delta.side-by-side=false",
            "diff",
            "HEAD",
            "--",
            rel_path .. entry.value,
          }
        end,
      }),
    })
    :find()
end

M.mapkey = function(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

function M.cowboy()
  ---@type table?
  local id
  local ok = true
  for _, key in ipairs({ "h", "j", "k", "l", "+", "-" }) do
    local count = 0
    local timer = assert(vim.loop.new_timer())
    local map = key
    vim.keymap.set("n", key, function()
      if vim.v.count > 0 then
        count = 0
      end
      if count >= 10 then
        ok, id = pcall(vim.notify, "Hold it Cowboy!", vim.log.levels.WARN, {
          icon = "🤠",
          replace = id,
          keep = function()
            return count >= 10
          end,
        })
        if not ok then
          id = nil
          return map
        end
      else
        count = count + 1
        timer:start(2000, 0, function()
          count = 0
        end)
        return map
      end
    end, { expr = true, silent = true })
  end
end

-- M.caqtlink = function()
-- vim.uv.fs_symlink("ui.lua", "z1")
-- vim.uv.fs_unlink("z1")
-- print(vim.fn.fnamemodify(vim.fn.getcwd(), ":h:t"))
-- end

return M
