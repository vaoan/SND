--[=====[
[[SND Metadata]]
author: 'Heiner'
version: 1.0.0
description: Test script to check Questionable IPC and quest status
[[End Metadata]]
--]=====]

-- Script Version (keep in sync with metadata!)
local SCRIPT_VERSION = "1.0.0"

yield("/echo [TestQuestionable] === Testing Questionable IPC v" .. SCRIPT_VERSION .. " ===")

-- Check if IPC exists
if not IPC then
    yield("/echo [TestQuestionable] ERROR: IPC is nil")
    return
end
yield("/echo [TestQuestionable] IPC exists: YES")

if not IPC.Questionable then
    yield("/echo [TestQuestionable] ERROR: IPC.Questionable is nil")
    return
end
yield("/echo [TestQuestionable] IPC.Questionable exists: YES")

-- Test IsRunning first (no parameters)
yield("/echo [TestQuestionable] Testing IsRunning()...")
local running = IPC.Questionable.IsRunning()
yield("/echo [TestQuestionable] IsRunning = " .. tostring(running))

-- Test IsQuestComplete with string ID
yield("/echo [TestQuestionable] Testing IsQuestComplete with string '67631'...")
local complete = IPC.Questionable.IsQuestComplete("67631")
yield("/echo [TestQuestionable] IsQuestComplete('67631') = " .. tostring(complete))

-- Check what's available in global scope for quest checking
yield("/echo [TestQuestionable] --- Checking Available APIs ---")

-- Check if there's a Quest or QuestManager global
if Quest then
    yield("/echo [TestQuestionable] Quest global exists")
else
    yield("/echo [TestQuestionable] Quest global is nil")
end

-- Check Player for quest methods
yield("/echo [TestQuestionable] Checking Player methods...")
if Player then
    if Player.IsQuestComplete then
        yield("/echo [TestQuestionable] Player.IsQuestComplete exists")
    end
    if Player.HasQuest then
        yield("/echo [TestQuestionable] Player.HasQuest exists")
    end
end

-- Check if we can use IsQuestComplete as global function
if IsQuestComplete then
    yield("/echo [TestQuestionable] IsQuestComplete global exists")
    local result = IsQuestComplete(67631)
    yield("/echo [TestQuestionable] IsQuestComplete(67631) = " .. tostring(result))
else
    yield("/echo [TestQuestionable] IsQuestComplete global is nil")
end

yield("/echo [TestQuestionable] === Test Complete ===")
