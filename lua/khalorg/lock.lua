local M = {}
local held = {}

---Prevent overlapping calendar operations and writes to the same Org file.
function M.acquire(target)
  local keys = { "calendar:" .. target.executable .. ":" .. target.calendar }
  if target.org_file then
    keys[#keys + 1] = "file:" .. target.org_file
  end
  for _, key in ipairs(keys) do
    if held[key] then
      return nil, "A Khalorg operation is already running for this calendar or file"
    end
  end
  for _, key in ipairs(keys) do
    held[key] = true
  end
  local released = false
  return function()
    if released then
      return
    end
    released = true
    for _, key in ipairs(keys) do
      held[key] = nil
    end
  end
end

return M
