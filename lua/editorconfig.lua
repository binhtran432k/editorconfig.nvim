local is_win_3f = (vim.fn.has("win32") == 1)
local apply = {}
apply.charset = function(bufnr, val)
  assert(vim.tbl_contains({"utf-8", "utf-8-bom", "latin1", "utf-16be", "utf-16le"}, val))
  if ((val == "utf-8") or (val == "utf-8-bom")) then
    vim.api.nvim_buf_set_option(bufnr, "fileencoding", "utf-8")
    return vim.api.nvim_buf_set_option(bufnr, "bomb", (val == "utf-8-bom"))
  else
    return vim.api.nvim_buf_set_option(bufnr, "fileencoding", val)
  end
end
apply.end_of_line = function(bufnr, val)
  return vim.api.nvim_buf_set_option(bufnr, "fileformat", assert(({cr = "mac", crlf = "dos", lf = "unix"})[val]))
end
apply.indent_style = function(bufnr, val, opts)
  assert(((val == "tab") or (val == "space")))
  vim.api.nvim_buf_set_option(bufnr, "expandtab", (val == "space"))
  if ((val == "tab") and not opts.indent_size) then
    vim.api.nvim_buf_set_option(bufnr, "shiftwidth", 0)
    return vim.api.nvim_buf_set_option(bufnr, "softtabstop", 0)
  end
end
apply.indent_size = function(bufnr, val, opts)
  if (val == "tab") then
    vim.api.nvim_buf_set_option(bufnr, "shiftwidth", 0)
    return vim.api.nvim_buf_set_option(bufnr, "softtabstop", 0)
  else
    local n = assert(tonumber(val))
    vim.api.nvim_buf_set_option(bufnr, "shiftwidth", n)
    vim.api.nvim_buf_set_option(bufnr, "softtabstop", -1)
    if not opts.tab_width then
      return vim.api.nvim_buf_set_option(bufnr, "tabstop", n)
    end
  end
end
apply.tab_width = function(bufnr, val)
  return vim.api.nvim_buf_set_option(bufnr, "tabstop", assert(tonumber(val)))
end
apply.max_line_length = function(bufnr, val)
  return vim.api.nvim_buf_set_option(bufnr, "textwidth", assert(tonumber(val)))
end
apply.trim_trailing_whitespace = function(bufnr, val)
  assert(((val == "true") or (val == "false")))
  if (val == "true") then
    return vim.api.nvim_command("autocmd! editorconfig BufWritePre <buffer> lua require('editorconfig').trim_trailing_whitespace()")
  end
end
apply.insert_final_newline = function(bufnr, val)
  assert(((val == "true") or (val == "false")))
  if (val ~= "true") then
    vim.api.nvim_buf_set_option(bufnr, "fixendofline", false)
    return vim.api.nvim_buf_set_option(bufnr, "endofline", false)
  end
end
local function glob2regpat(glob)
  local placeholder = "@@PLACEHOLDER@@"
  return string.gsub(vim.fn.glob2regpat(vim.fn.substitute(string.gsub(glob, "{(%d+)%.%.(%d+)}", "[%1-%2]"), "\\*\\@<!\\*\\*\\@!", placeholder, "g")), placeholder, "[^/]*")
end
local function convert_pathseps(path)
  if is_win_3f then
    return path:gsub("/", "\\")
  else
    return path
  end
end
local function dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end
local function parseline(line)
  if line:find("^%s*[^ #;]") then
    local _8_ = ((line:match("%b[]") or "")):match("%[([^%]]+)")
    if (nil ~= _8_) then
      local glob = _8_
      return glob, nil, nil
    else
      local _ = _8_
      local _9_, _10_ = line:match("^%s*([^:= ][^:=]-)%s*[:=]%s*(.-)%s*$")
      if ((nil ~= _9_) and (nil ~= _10_)) then
        local key = _9_
        local val = _10_
        return nil, key:lower(), val:lower()
      end
    end
  end
end
local function parse(filepath, dir)
  local pat = nil
  local opts = {}
  do
    local f = io.open((dir .. "/.editorconfig"))
    if f then
      for line in f:lines() do
        local _14_, _15_, _16_ = parseline(line)
        if (nil ~= _14_) then
          local glob = _14_
          local glob0
          if glob:find("/") then
            glob0 = (dir .. "/" .. glob:gsub("^/", ""))
          else
            glob0 = ("**/" .. glob)
          end
          pat = vim.regex(convert_pathseps(glob2regpat(glob0)))
        elseif ((_14_ == nil) and (nil ~= _15_) and (nil ~= _16_)) then
          local key = _15_
          local val = _16_
          if (key == "root") then
            opts["root"] = (val == "true")
          elseif (pat and pat:match_str(filepath)) then
            opts[key] = val
          end
        end
      end
      f:close()
    end
  end
  return opts
end
local function config(bufnr)
  local bufnr0 = (bufnr or vim.api.nvim_get_current_buf())
  local path = vim.api.nvim_buf_get_name(bufnr0)
  if ((vim.api.nvim_buf_get_option(bufnr0, "buftype") == "") and vim.api.nvim_buf_get_option(bufnr0, "modifiable") and (path ~= "")) then
    local opts = {}
    local curdir = dirname(path)
    local done_3f = false
    while not done_3f do
      for k, v in pairs(parse(path, curdir)) do
        if (opts[k] == nil) then
          opts[k] = v
        end
      end
      if opts.root then
        done_3f = true
      else
        local parent = dirname(curdir)
        if (parent == curdir) then
          done_3f = true
        else
          curdir = parent
        end
      end
    end
    for opt, val in pairs(opts) do
      if (val ~= "unset") then
        local _24_ = apply[opt]
        if (nil ~= _24_) then
          local func = _24_
          if not pcall(func, bufnr0, val, opts) then
            vim.notify(("editorconfig: invalid value for option %s: %s"):format(opt, val), vim.log.levels.WARN)
          end
        end
      end
    end
    return nil
  end
end
local function trim_trailing_whitespace()
  local view = vim.fn.winsaveview()
  vim.api.nvim_command("silent keepjumps keeppatterns %s/\\s\\+$//e")
  return vim.fn.winrestview(view)
end
return {config = config, trim_trailing_whitespace = trim_trailing_whitespace}
