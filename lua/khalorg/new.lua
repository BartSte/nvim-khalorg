local process = require("khalorg.process")
local org = require("khalorg.org")
local ui = require("khalorg.ui")
local M = {}
local format = "{uid}\t{title}\t{timestamps}"

-- Compare dates and times, independent of weekday labels and Org repeaters.
local function signature(timestamp)
  local dates, times = {}, {}
  for date in timestamp:gmatch("%d%d%d%d%-%d%d%-%d%d") do dates[#dates + 1] = date end
  for time in timestamp:gmatch("%d%d:%d%d") do times[#times + 1] = time end
  assert(#dates >= 1 and #dates <= 2 and #times <= 2, "Invalid event timestamp in calendar output")
  local start_date, end_date = dates[1], dates[2] or dates[1]
  if #times == 1 then
    local hour, minute = times[1]:match("(%d%d):(%d%d)")
    hour = tonumber(hour) + 1
    if hour == 24 then
      hour = 0
      local year, month, day = end_date:match("(%d+)%-(%d+)%-(%d+)")
      end_date = os.date("%Y-%m-%d", os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) + 1, hour = 12 }))
    end
    times[2] = string.format("%02d:%s", hour, minute)
  end
  return table.concat({ start_date, times[1] or "", end_date, times[2] or "" }, "|")
end

local function title(headline)
  local value = vim.trim(headline:gsub("^%*+%s+", ""))
  value = value:gsub("%s*:[%w_@:]+:%s*$", "")
  value = value:gsub("^TODO ", ""):gsub("^DONE ", "")
  value = value:gsub("^%s*%[#%u%]%s?", ""):gsub("^%s*%[#%d%]%s?", "")
  value = value:gsub("%[%[[^%]]+%]%[([^%]]+)%]%]", "%1"):gsub("%[%[([^%]]+)%]%]", "%1")
  return vim.trim(value)
end

local function records(text)
  local result, current = {}, nil
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if vim.trim(line) ~= "" then
      local uid, heading, timestamp = line:match("^([^\t]+)\t([^\t]*)\t([^\t]+)$")
      if uid then
        assert(not uid:find("[\r\n]") and not result[uid], "Invalid or duplicate UID in calendar output")
        current = { title = heading, timestamps = { signature(timestamp) } }
        result[uid] = current
      else
        assert(current and line:match("^%s*<") and not line:find("\t"), "Unrecognized calendar output. UID writeback requires list --format support.")
        current.timestamps[#current.timestamps + 1] = signature(line)
      end
    end
  end
  return result
end

function M.run(target, opts, report)
  local ok, source = pcall(org.capture)
  if not ok or source.text == "" then
    ui.error(ok and "No agenda item found under the cursor" or source)
    return
  end
  if org.uid(source) then
    ui.error("This event already has a UID. Use edit() to update it.")
    return
  end
  local wanted_title = title(source.headline)
  local wanted_time = signature(source.timestamp)
  local date, day = source.timestamp:match("^<(%d%d%d%d%-%d%d%-%d%d)%s+([^%d%s>]+)")
  if not date then
    date = source.timestamp:match("%d%d%d%d%-%d%d%-%d%d")
    local year, month, month_day = date:match("(%d+)%-(%d+)%-(%d+)")
    day = os.date("%a", os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(month_day), hour = 12 }))
  end
  date = date .. " " .. day
  local argv = { target.executable, "list", "--format", format, "--", target.calendar, date, "1d" }
  local release, err = require("khalorg.lock").acquire(target)
  if not release then ui.error(err); return end

  local function finish(result, uid)
    release()
    report(result)
    if opts.on_complete then opts.on_complete(result, uid) end
  end
  local function read(callback, created)
    return process.run(argv, nil, function(result)
      local parsed, events = pcall(records, result.stdout or "")
      if result.code ~= 0 or not parsed then
        local message = "Cannot read event UIDs: " .. (parsed and (result.stderr or "") or tostring(events))
        if created then message = "The event creation command finished. " .. message end
        finish({ code = -1, stdout = "", stderr = message })
        return
      end
      callback(events)
    end)
  end
  local function matches(event)
    return event.title == wanted_title and vim.tbl_contains(event.timestamps, wanted_time)
  end
  return read(function(before)
    for _, event in pairs(before) do
      if matches(event) then
        release()
        ui.error("A matching calendar event already exists. Import or sync it to obtain its UID.")
        return
      end
    end
    if not org.unchanged(source) then
      release()
      ui.error("The source buffer changed before event creation. Run new() again.")
      return
    end
    process.run({ target.executable, "new", "--", target.calendar }, source.text, function(result)
      if result.code ~= 0 then
        finish(result)
        return
      end
      read(function(after)
        local candidates = {}
        for uid, event in pairs(after) do
          if not before[uid] and matches(event) then candidates[#candidates + 1] = uid end
        end
        local uid = #candidates == 1 and candidates[1] or nil
        local warning
        if uid then
          local written, reason = org.write_uid(source, uid)
          if not written then
            warning = "Khalorg created the event. " .. reason
          end
        else
          warning = "Khalorg creation finished, but a unique new event UID was not found. The source buffer remains unchanged. Use list or sync to inspect the calendar."
        end
        finish(result, uid)
        if warning then vim.notify(warning, vim.log.levels.WARN) end
      end, true)
    end)
  end)
end

return M
