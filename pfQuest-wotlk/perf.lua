local addonName = "pfQuest-wotlk"

local function EnsurePerfFrame()
  if not pfQuestPerf then
    if type(CreateFrame) == "function" then
      pfQuestPerf = CreateFrame("Frame", "pfQuestPerformanceHarness")
    end

    if not pfQuestPerf then
      pfQuestPerf = {}
    end
  end

  pfQuestPerf.snapshots = pfQuestPerf.snapshots or {}
  return pfQuestPerf
end

pfQuestPerf_Ensure = EnsurePerfFrame
_G.pfQuestPerf_Ensure = EnsurePerfFrame

local perf = EnsurePerfFrame()
pfQuestPerf = perf
_G.pfQuestPerf = perf
pfQuestPerf_Ensure = EnsurePerfFrame
_G.pfQuestPerf_Ensure = EnsurePerfFrame
SlashCmdList = SlashCmdList or {}
SLASH_PFPERF1 = SLASH_PFPERF1 or "/pfperf"
SlashCmdList["PFPERF"] = function(msg)
  if not perf or not perf.Snapshot then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest:|r perf module not ready")
    return
  end
  local sub, label = msg:match("^(%S+)%s*(.*)$")
  sub = sub and sub:lower() or "help"
  if sub == "snapshot" then
    perf:Snapshot(label ~= "" and label or nil)
  elseif sub == "report" then
    perf:Report()
  elseif sub == "clear" then
    perf:Clear()
  else
    perf:Help()
  end
end
perf.addonName = addonName

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest|r: " .. msg)
  end
end

local function FormatKB(kb)
  if not kb then return "n/a" end
  return string.format("%.2f MB", kb / 1024)
end

local function FormatSeconds(sec)
  if not sec then return "n/a" end
  return string.format("%.3f s", sec)
end

local function SnapshotDelta(current, previous)
  if not previous then return nil end
  return {
    memory = current.memory and previous.memory and (current.memory - previous.memory) or nil,
    totalMemory = current.totalMemory and previous.totalMemory and (current.totalMemory - previous.totalMemory) or nil,
    cpu = current.cpu and previous.cpu and (current.cpu - previous.cpu) or nil,
    scriptCPU = current.scriptCPU and previous.scriptCPU and (current.scriptCPU - previous.scriptCPU) or nil,
    took = current.timestamp - previous.timestamp,
  }
end

local function DescribeDelta(prefix, value, unitFormatter)
  if not value then
    return prefix .. ": n/a"
  end

  local formatted = unitFormatter(math.abs(value))
  if value >= 0 then
    return string.format("%s: +%s", prefix, formatted)
  else
    return string.format("%s: -%s", prefix, formatted)
  end
end

function perf:Snapshot(label)
  UpdateAddOnMemoryUsage()
  local now = GetTime()
  local memory = GetAddOnMemoryUsage(self.addonName)
  local totalMemoryKB = collectgarbage("count")
  local cpuUsage, scriptCPUUsage

  if GetAddOnCPUUsage and GetCVar and GetCVar("scriptProfile") == "1" then
    cpuUsage = GetAddOnCPUUsage(self.addonName)
    scriptCPUUsage = GetScriptCPUUsage and GetScriptCPUUsage() or nil
  end

  local snapshot = {
    label = label or string.format("snapshot-%d", #self.snapshots + 1),
    timestamp = now,
    memory = memory,
    totalMemory = totalMemoryKB,
    cpu = cpuUsage,
    scriptCPU = scriptCPUUsage,
    framerate = GetFramerate(),
  }

  table.insert(self.snapshots, snapshot)
  self:PrintSnapshot(snapshot)

  local previous = #self.snapshots > 1 and self.snapshots[#self.snapshots - 1] or nil
  if previous then
    self:PrintDelta(snapshot, previous)
  end

  return snapshot
end

function perf:PrintSnapshot(snapshot)
  local label = snapshot.label or "snapshot"
  local lines = {
    string.format("|cffffff88%s|r @ %.2fs", label, snapshot.timestamp),
    "  AddOn memory: " .. FormatKB(snapshot.memory),
    "  Total Lua memory: " .. FormatKB(snapshot.totalMemory),
    string.format("  Frame rate: %.1f fps", snapshot.framerate or 0),
  }

  if GetAddOnCPUUsage then
    if GetCVar("scriptProfile") ~= "1" then
      table.insert(lines, "  CPU usage: |cffff6666scriptProfile disabled|r (/console scriptProfile 1)")
    else
      table.insert(lines, "  AddOn CPU: " .. FormatSeconds(snapshot.cpu))
      table.insert(lines, "  Script CPU: " .. FormatSeconds(snapshot.scriptCPU))
    end
  end

  for _, line in ipairs(lines) do
    Print(line)
  end
end

function perf:PrintDelta(current, previous)
  local delta = SnapshotDelta(current, previous)
  if not delta then return end

  local lines = {
    string.format("  Δ since %s (%.2fs):", previous.label or "previous", delta.took or 0),
    "    " .. DescribeDelta("AddOn memory", delta.memory, FormatKB),
    "    " .. DescribeDelta("Total memory", delta.totalMemory, FormatKB),
  }

  if delta.cpu then
    table.insert(lines, "    " .. DescribeDelta("AddOn CPU", delta.cpu, function(v)
      return FormatSeconds(v)
    end))
  end

  if delta.scriptCPU then
    table.insert(lines, "    " .. DescribeDelta("Script CPU", delta.scriptCPU, function(v)
      return FormatSeconds(v)
    end))
  end

  for _, line in ipairs(lines) do
    Print(line)
  end
end

function perf:Report()
  local total = #self.snapshots
  if total == 0 then
    Print("No performance snapshots recorded. Use |cffffff88/db perf snapshot|r first.")
    return
  end

  Print(string.format("Performance report (%d snapshots)", total))
  for index, snapshot in ipairs(self.snapshots) do
    Print(string.format("%d) %s", index, snapshot.label or ("snapshot-" .. index)))
    Print(string.format("    Memory: %s (total %s)",
      FormatKB(snapshot.memory),
      FormatKB(snapshot.totalMemory)))

    if GetAddOnCPUUsage and GetCVar("scriptProfile") == "1" then
      Print(string.format("    CPU: %s (script %s)",
        FormatSeconds(snapshot.cpu),
        FormatSeconds(snapshot.scriptCPU)))
    end

    Print(string.format("    FPS: %.1f", snapshot.framerate or 0))
  end
end

function perf:Clear()
  wipe(self.snapshots)
  Print("Cleared performance snapshots.")
end

function perf:Help()
  Print("Performance capture commands:")
  Print("  |cffffff88/db perf snapshot [label]|r - record current metrics")
  Print("  |cffffff88/db perf report|r - show collected snapshot summary")
  Print("  |cffffff88/db perf clear|r - remove all snapshots")
  Print("Enable CPU profiling with |cffffff88/console scriptProfile 1|r for CPU metrics (requires /reload).")
end

