--[=====[
[[SND Metadata]]
author: 'Heiner'
version: 2.0.0
description: Displays all job/class levels for the current character
[[End Metadata]]
--]=====]

-- Script Version (keep in sync with metadata!)
local SCRIPT_VERSION = "2.0.0"

yield("/echo [ShowAllLevels] === Character Job Levels v" .. SCRIPT_VERSION .. " ===")

-- Get ClassJob sheet for names
local classJobSheet = Excel.GetSheet("ClassJob")
if not classJobSheet then
    yield("/echo [ShowAllLevels] ERROR: Could not load ClassJob sheet")
    return
end

-- Get current job for marking
local lp = Svc.ClientState.LocalPlayer
local currentJobId = lp and lp.ClassJob and lp.ClassJob.RowId or 0

-- Iterate all jobs and show levels
for jobId = 1, 42 do
    local job = Player.GetJob(jobId)
    if job and job.Level and job.Level > 0 then
        local jobRow = classJobSheet:GetRow(jobId)
        local abbr = jobRow and tostring(jobRow.Abbreviation) or "?"
        local name = jobRow and tostring(jobRow.Name) or "Unknown"

        local marker = ""
        if jobId == currentJobId then
            marker = " [CURRENT]"
        end

        yield("/echo [ShowAllLevels] " .. abbr .. " (" .. name .. "): Lv." .. tostring(job.Level) .. marker)
    end
end

yield("/echo [ShowAllLevels] === Done ===")
