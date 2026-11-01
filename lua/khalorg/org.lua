local M = {}

local function section_at_cursor()
  vim.treesitter.get_parser(0, "org"):parse()
  local node = vim.treesitter.get_node({ lang = "org" })
  while node and node:type() ~= "section" do
    node = node:parent()
  end
  assert(node, "No fold found under the cursor")
  return node
end

function M.capture()
  local bufnr = vim.api.nvim_get_current_buf()
  local section = section_at_cursor()
  local first, _, last = section:range()
  for child in section:iter_children() do
    if child:type() == "section" then
      last = child:start()
      break
    end
  end
  local function text(field)
    local node = section:field(field)[1]
    return node and vim.treesitter.get_node_text(node, bufnr) or ""
  end
  local timestamps = {}
  local query = vim.treesitter.query.parse("org", "(timestamp) @timestamp")
  for _, node in query:iter_captures(section, bufnr, first, last) do
    if node:start() < last then
      local value = vim.treesitter.get_node_text(node, bufnr)
      if value:sub(1, 1) == "<" then
        timestamps[#timestamps + 1] = { node = node, text = value }
      end
    end
  end
  local source = { bufnr = bufnr, tick = vim.api.nvim_buf_get_changedtick(bufnr),
    name = vim.api.nvim_buf_get_name(bufnr), text = "", first = first, last = last }
  if #timestamps == 0 then
    return source
  end
  assert(#timestamps == 1, "Multiple event timestamps found. Keep one timestamp or one explicit Org date range.")
  local plan = section:field("plan")[1]
  assert(plan and timestamps[1].node:parent():parent() == plan, "Place the event timestamp directly below its headline.")
  source.timestamp = timestamps[1].text
  source.headline = text("headline")
  source.properties = text("property_drawer")
  source.text = table.concat({ source.headline, source.timestamp, source.properties, text("body") }, "\n")
  local row, col = plan:end_()
  source.insert_row = col == 0 and row or row + 1
  local drawer = section:field("property_drawer")[1]
  if drawer then
    source.drawer_first = drawer:start()
    source.drawer_last = drawer:end_()
  end
  return source
end

function M.unchanged(source)
  return vim.api.nvim_buf_is_valid(source.bufnr)
    and vim.api.nvim_buf_is_loaded(source.bufnr)
    and vim.api.nvim_buf_get_name(source.bufnr) == source.name
    and vim.api.nvim_buf_get_changedtick(source.bufnr) == source.tick
    and vim.bo[source.bufnr].modifiable
end

function M.uid(source)
  for line in source.properties:gmatch("[^\n]+") do
    local value = line:match("^%s*:[Uu][Ii][Dd]:%s*(.-)%s*$")
    if value and value ~= "" then
      return value
    end
  end
end

function M.write_uid(source, uid)
  if not M.unchanged(source) then
    return nil, "The source buffer changed. UID " .. uid .. " was not written."
  end
  if source.drawer_first then
    local lines = vim.api.nvim_buf_get_lines(source.bufnr, source.drawer_first, source.drawer_last, false)
    for i, line in ipairs(lines) do
      local indent = line:match("^(%s*):[Uu][Ii][Dd]:")
      if indent then
        vim.api.nvim_buf_set_lines(source.bufnr, source.drawer_first + i - 1, source.drawer_first + i, false, { indent .. ":UID: " .. uid })
        return true
      end
    end
    for i, line in ipairs(lines) do
      local indent = line:match("^(%s*):[Ee][Nn][Dd]:%s*$")
      if indent then
        local row = source.drawer_first + i - 1
        vim.api.nvim_buf_set_lines(source.bufnr, row, row, false, { indent .. ":UID: " .. uid })
        return true
      end
    end
    return nil, "The property drawer has no END marker. UID " .. uid .. " was not written."
  end
  local timestamp_line = vim.api.nvim_buf_get_lines(source.bufnr, source.insert_row - 1, source.insert_row, false)[1] or ""
  local indent = timestamp_line:match("^%s*")
  vim.api.nvim_buf_set_lines(source.bufnr, source.insert_row, source.insert_row, false, {
    indent .. ":PROPERTIES:", indent .. ":UID: " .. uid, indent .. ":END:",
  })
  return true
end

return M
