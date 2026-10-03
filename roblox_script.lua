-- ╔════════════════════════════════════════════════════════════╗
-- ║   🔥 AngusHub x Hunter — ค่ายโปรล่าค่าหัว Blox Fruits       ║
-- ║   ⚡ Realtime Live Tracker v4.3                            ║
-- ║   🛡️ ระบบกันหลุด / กันรีจอยแล้วสคริปต์หาย (Auto-Reconnect)   ║
-- ║   อัพเดต Beli, Fragments, Bounty, Level และไอเทมเรียลไทม์   ║
-- ╚════════════════════════════════════════════════════════════╝

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- 🌐 เซิร์ฟเวอร์หลัก (AngusHub Cloud on Render)
local SERVER_URL = "https://angushubxhunter-n4sp.onrender.com"

-- ════════════════════════════════════════════════════════════
--  🛡️ SINGLETON GUARD (ป้องกันสคริปต์รันซ้ำซ้อนเวลารีจอย)
-- ════════════════════════════════════════════════════════════
if getgenv().ANGUSHUB_RUNNING and getgenv().ANGUSHUB_JOB_ID == game.JobId then
    print("[AngusHub] Script is already active in this server (JobId: " .. tostring(game.JobId) .. ")! Skipping duplicate execution.")
    return
end

getgenv().ANGUSHUB_RUNNING = true
getgenv().ANGUSHUB_JOB_ID = game.JobId

-- รหัส Session ประจำการรันรอบนี้ (เธรด/ลูปเก่าจะหยุดทำงานอัตโนมัติ)
local CURRENT_SESSION_ID = tick()
getgenv().ANGUSHUB_SESSION_ID = CURRENT_SESSION_ID

-- ล้าง UI เก่าออกทั้งหมดก่อนสร้างใหม่
if getgenv().ANGUSHUB_CLEANUP then
    pcall(getgenv().ANGUSHUB_CLEANUP)
end

getgenv().ANGUSHUB_CLEANUP = function()
    pcall(function()
        local pGui = (gethui and gethui()) or game:GetService("CoreGui") or LP:FindFirstChild("PlayerGui")
        if pGui then
            for _, gName in ipairs({"AngusHubMainGui", "AngusHubToggleGui", "AngusHubBadge", "AngusHubNotifGui", "AngusHubESP"}) do
                local g = pGui:FindFirstChild(gName)
                if g then g:Destroy() end
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════
--  🔄 AUTO RE-EXECUTE ON REJOIN & TELEPORT (ข้ามเซิร์ฟ / รีจอย)
-- ════════════════════════════════════════════════════════════
local queue_on_teleport = (syn and syn.queue_on_teleport)
    or queue_on_teleport
    or (fluxus and fluxus.queue_on_teleport)
    or (getgenv and getgenv().queue_on_teleport)

local autoRejoinCode = 'repeat task.wait() until game:IsLoaded()\ntask.wait(1)\nif not (getgenv().ANGUSHUB_RUNNING and getgenv().ANGUSHUB_JOB_ID == game.JobId) then loadstring(game:HttpGet("' .. SERVER_URL .. '/script.lua"))() end'

-- Debounce: สั่งคิวแค่รอบเดียวเท่านั้น ป้องกันเบิ้ลซ้ำซ้อนจนเครื่องค้าง
local teleportQueued = false
local function safelyQueueRejoin()
    if teleportQueued then return end
    teleportQueued = true
    if queue_on_teleport then
        pcall(queue_on_teleport, autoRejoinCode)
    end
end

-- สั่งคิวล่วงหน้า 1 ครั้ง
safelyQueueRejoin()

pcall(function()
    LP.OnTeleport:Connect(function(state)
        getgenv().ANGUSHUB_JOB_ID = nil
        getgenv().ANGUSHUB_RUNNING = false
        safelyQueueRejoin()
    end)
end)

-- ════════════════════════════════════════════════════════════
--  🛡️ AUTO RECONNECT ON DISCONNECT / KICK (ป้องกันหลุด)
-- ════════════════════════════════════════════════════════════
task.spawn(function()
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local TeleportService = game:GetService("TeleportService")
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 8)
        if promptOverlay then
            local overlay = promptOverlay:WaitForChild("promptOverlay", 8)
            if overlay then
                overlay.ChildAdded:Connect(function(child)
                    if child.Name == "ErrorPrompt" then
                        task.wait(2)
                        pcall(function()
                            if #Players:GetPlayers() <= 1 then
                                TeleportService:Teleport(game.PlaceId, LP)
                            else
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
                            end
                        end)
                    end
                end)
            end
        end
    end)
end)

-- ════════════════════════════════════════════════════════════
--  🏴‍☠️ AUTO SELECT TEAM & WAIT FOR DATA ON REJOIN
-- ════════════════════════════════════════════════════════════
task.spawn(function()
    pcall(function()
        local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 8)
        local commF = remotes and remotes:WaitForChild("CommF_", 8)
        if commF and (not LP.Team or LP.Team.Name == "Neutral" or LP.Team.Name == "") then
            pcall(function() commF:InvokeServer("SetTeam", "Pirates") end)
        end
    end)
end)

local function ensureDataLoaded()
    local t0 = tick()
    while tick() - t0 < 8 do
        if LP:FindFirstChild("Data") or LP:FindFirstChild("leaderstats") then
            break
        end
        task.wait(0.4)
    end
end
ensureDataLoaded()

local function extractAssetId(tex)
    if not tex or tex == "" then return nil end
    return tex:match("(%d+)")
end

local function scanItem(item)
    local info = {
        name = item.Name,
        className = item.ClassName,
        textureId = "",
        assetId = nil,
        toolTip = "",
        category = "Other"
    }
    if item:IsA("Tool") then
        info.textureId = item.TextureId or ""
        info.assetId = extractAssetId(info.textureId)
        info.toolTip = item.ToolTip or ""
    end
    return info
end

local lastBounty = 0
local lastBeli = 0
local lastFrags = 0
local lastLevel = 0
local lastFruit = "None"
local lastSea = "Blox Fruits"
local lastSyncTime = "-"
local onTrackerDataUpdated = nil

local function parseNumber(val)
    if type(val) == "number" then
        return math.floor(val)
    end
    local s = tostring(val or "")
    if s == "" then return 0 end

    -- ตรวจจับรูปแบบตัวเลข เช่น "7.94M", "7.944M" หรือ "500K"
    local numStr, unit = s:match("([%d%,%.]+)%s*([KkMmBb]?)")
    if numStr then
        local clean = numStr:gsub(",", "")
        local n = tonumber(clean)
        if n then
            local u = (unit or ""):upper()
            if u == "M" then
                return math.floor(n * 1000000)
            elseif u == "K" then
                return math.floor(n * 1000)
            elseif u == "B" then
                return math.floor(n * 1000000000)
            else
                return math.floor(n)
            end
        end
    end

    local digits = s:gsub("%D", "")
    return tonumber(digits) or 0
end

-- ฟังก์ชันค้นหาค่าหัว (Bounty / Honor) ตรงจาก leaderstats แบบแม่นยำ 100% ไม่ปัดเศษ
local function getPlayerBounty()
    -- 1) leaderstats (ค่าหัวจริงของตัวละครจาก Server 100% Raw Number เช่น 7,944,xxx)
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, c in pairs(ls:GetChildren()) do
            local cn = c.Name:lower()
            if cn:find("bounty") or cn:find("honor") then
                local v = parseNumber(c.Value)
                if v and v > 0 then
                    return v, "leaderstats." .. c.Name
                end
            end
        end
    end

    -- 2) Player.Data (ในกรณีที่เกมบันทึกใน Data folder)
    local d = LP:FindFirstChild("Data")
    if d then
        for _, c in pairs(d:GetChildren()) do
            local cn = c.Name:lower()
            if cn:find("bounty") or cn:find("honor") then
                local v = parseNumber(c.Value)
                if v and v > 0 then
                    return v, "Data." .. c.Name
                end
            end
        end
    end

    -- 3) GUI Fallback: หาเฉพาะ Label ค่าหัวของผู้เล่น โดยกรองเป้าหมาย 8M, 10M, 20M, 30M ออก
    if LP:FindFirstChild("PlayerGui") then
        local pg = LP.PlayerGui
        local main = pg:FindFirstChild("Main")
        if main then
            for _, desc in pairs(main:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible then
                    local dn = desc.Name:lower()
                    local pn = desc.Parent and desc.Parent.Name:lower() or ""
                    if dn:find("bounty") or dn:find("honor") or pn:find("bounty") or pn:find("honor") then
                        local txt = desc.Text
                        -- ข้ามเป้าหมายภารกิจหรือเพดานค่าหัว เช่น "Next: 8,000,000" หรือเลขเป้าหมาย
                        if not txt:lower():find("next") and not txt:lower():find("req") and not txt:find("/") then
                            local v = parseNumber(txt)
                            if v > 1000 and v ~= 8000000 and v ~= 10000000 and v ~= 20000000 and v ~= 30000000 then
                                return v, "PlayerGui." .. desc.Name
                            end
                        end
                    end
                end
            end
        end
    end

    return 0, "None"
end

local lastFullInvCheck = 0
local cachedFullInv = {}

local function getFullInventory()
    local now = tick()
    if now - lastFullInvCheck > 25 then
        lastFullInvCheck = now
        pcall(function()
            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            local commF = remotes and remotes:FindFirstChild("CommF_")
            if commF then
                local res = commF:InvokeServer("getInventory")
                if type(res) == "table" and #res > 0 then
                    cachedFullInv = res
                end
            end
        end)
    end
    return cachedFullInv
end

local function syncData()
    local inv = {}
    local seen = {}

    local function addTool(item, isEquipped, source)
        if item and item:IsA("Tool") then
            local name = item.Name
            if not seen[name] then
                seen[name] = true
                local i = scanItem(item)
                i.equipped = isEquipped
                i.source = source
                table.insert(inv, i)
            end
        end
    end

    -- 1) Character (Equipped Tools in player's hands)
    if LP.Character then
        for _, item in pairs(LP.Character:GetChildren()) do
            addTool(item, true, "Equipped")
        end
    end

    -- 2) Backpack (Hotbar & Carried Tools)
    if LP:FindFirstChild("Backpack") then
        for _, item in pairs(LP.Backpack:GetChildren()) do
            addTool(item, false, "Backpack")
        end
    end

    -- 3) Blox Fruits In-Game Storage Inventory (CommF_ getInventory)
    pcall(function()
        local fullList = getFullInventory()
        if type(fullList) == "table" then
            for _, it in pairs(fullList) do
                local itName = it.Name or it.name
                if itName and not seen[itName] then
                    seen[itName] = true
                    table.insert(inv, {
                        name = itName,
                        className = "Tool",
                        textureId = "",
                        assetId = nil,
                        toolTip = it.Type or it.type or "",
                        category = "Other",
                        equipped = false,
                        source = "Inventory"
                    })
                end
            end
        end
    end)

    -- 3) ดึงข้อมูล Live Stats
    local data = LP:FindFirstChild("Data")
    local beli = 0
    local frags = 0
    local level = 0
    local race = "Human"
    local fruit = "None"

    if data then
        if data:FindFirstChild("Beli") then beli = tonumber(data.Beli.Value) or 0 end
        if data:FindFirstChild("Fragments") then frags = tonumber(data.Fragments.Value) or 0 end
        if data:FindFirstChild("Level") then level = tonumber(data.Level.Value) or 0 end
        if data:FindFirstChild("Race") then race = tostring(data.Race.Value) end
        if data:FindFirstChild("DevilFruit") then fruit = tostring(data.DevilFruit.Value) end
    end

    -- ป้องกันค่าหาย (State Persistence)
    local bountyVal, bSource = getPlayerBounty()
    if bountyVal > 0 then
        lastBounty = bountyVal
    else
        bountyVal = lastBounty
    end
    if beli > 0 then lastBeli = beli else beli = lastBeli end
    if frags > 0 then lastFrags = frags else frags = lastFrags end
    if level > 0 then lastLevel = level else level = lastLevel end

    -- ตรวจสอบทะเล (Sea)
    local sea = "Blox Fruits"
    if game.PlaceId == 2753915549 then
        sea = "ทะเลที่ 1 (First Sea)"
    elseif game.PlaceId == 4442272183 then
        sea = "ทะเลที่ 2 (Second Sea)"
    elseif game.PlaceId == 7449423635 then
        sea = "ทะเลที่ 3 (Third Sea)"
    end

    -- เลือด (HP)
    local hpText = nil
    if LP.Character and LP.Character:FindFirstChild("Humanoid") then
        local hum = LP.Character.Humanoid
        hpText = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
    end

    -- ฝั่ง (Team: Pirates หรือ Marines)
    local teamName = "Pirates"
    if LP.Team then teamName = LP.Team.Name end

    local payload = {
        user_id = tostring(LP.UserId),
        username = LP.Name,
        display_name = LP.DisplayName,
        place_id = tostring(game.PlaceId),
        game_name = "Blox Fruits",
        sea = sea,
        team = teamName,
        beli = beli,
        fragments = frags,
        bounty = bountyVal,
        bounty_source = bSource,
        level = level,
        max_level = 3000,
        race = race,
        devil_fruit = fruit,
        inventory = inv,
        health = hpText
    }

    local jsonOk, jsonData = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not jsonOk or not jsonData then
        return false, "JSON encode error", bountyVal, bSource
    end

    local function sendHttpRequest(url, body)
        local HttpRequest = (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
            or (fluxus and fluxus.request)
            or (getgenv and (getgenv().request or getgenv().http_request or (getgenv().syn and getgenv().syn.request) or (getgenv().http and getgenv().http.request)))

        if HttpRequest then
            local ok, res = pcall(HttpRequest, {
                Url = url,
                url = url,
                Method = "POST",
                method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                headers = {["Content-Type"] = "application/json"},
                Body = body,
                body = body
            })
            if ok and res then return true, res end
        end

        local ok2, res2 = pcall(function()
            if game.HttpPost then
                return game:HttpPost(url, body, false, "application/json")
            end
        end)
        if ok2 and res2 then return true, res2 end

        local ok3, res3 = pcall(function()
            if game.HttpPostAsync then
                return game:HttpPostAsync(url, body)
            end
        end)
        if ok3 and res3 then return true, res3 end

        return false, "No HTTP POST capability found in executor"
    end

    local ok, res = sendHttpRequest(SERVER_URL .. "/api/inventory", jsonData)
    if not ok then
        task.wait(1.5)
        ok, res = sendHttpRequest(SERVER_URL .. "/api/inventory", jsonData)
    end

    lastFruit = fruit
    lastSea = sea
    lastSyncTime = os.date("%H:%M:%S")
    if onTrackerDataUpdated then
        pcall(onTrackerDataUpdated)
    end

    return ok, res, bountyVal, bSource
end

-- ════════════════════════════════════════════════════════════
--  🎨 โหลดโลโก้ค่าย AngusHub x Hunter & ระบบแจ้งเตือนพรีเมียม
-- ════════════════════════════════════════════════════════════
local clanLogoAsset = "rbxassetid://7072721868"
pcall(function()
    local getasset = getcustomasset or getsynasset
    if writefile and isfile and getasset then
        if not isfile("angushub_logo.png") then
            local ok, imgData = pcall(function()
                return game:HttpGet(SERVER_URL .. "/static/logo.jpg")
            end)
            if not ok or not imgData or #imgData < 500 then
                pcall(function()
                    imgData = game:HttpGet("https://angushubxhunter-n4sp.onrender.com/static/logo.jpg")
                end)
            end
            if imgData and #imgData > 500 then
                pcall(writefile, "angushub_logo.png", imgData)
                pcall(writefile, "angushub_logo.jpg", imgData)
            end
        end
        if isfile("angushub_logo.png") then
            clanLogoAsset = getasset("angushub_logo.png")
        elseif isfile("angushub_logo.jpg") then
            clanLogoAsset = getasset("angushub_logo.jpg")
        end
    end
end)

-- ฟังก์ชันแจ้งเตือนพร้อมรูปโลโก้ค่าย AngusHub x Hunter (รับประกันโลโก้ขึ้น 100%)
local function showClanNotification(title, message, duration)
    duration = duration or 5
    title = title or "🔥 AngusHub x Hunter"
    message = message or ""

    -- 1) แจ้งเตือนแบบมาตรฐานของเกม (StarterGui) พร้อมใส่ Icon โลโก้
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = message,
            Icon = clanLogoAsset,
            Duration = duration
        })
    end)

    -- 2) Custom In-Game Animated Banner พร้อมรูปโลโก้ค่าย คมชัด สวยงาม
    pcall(function()
        local parentGui = (gethui and gethui()) or game:GetService("CoreGui") or LP:WaitForChild("PlayerGui")
        local notifGui = parentGui:FindFirstChild("AngusHubNotifGui")
        if not notifGui then
            notifGui = Instance.new("ScreenGui")
            notifGui.Name = "AngusHubNotifGui"
            notifGui.ResetOnSpawn = false
            notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            notifGui.Parent = parentGui
        end

        local oldCard = notifGui:FindFirstChild("NotifCard")
        if oldCard then
            oldCard:Destroy()
        end

        local card = Instance.new("Frame")
        card.Name = "NotifCard"
        card.Size = UDim2.new(0, 310, 0, 70)
        card.Position = UDim2.new(1, 20, 0, 70)
        card.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.Parent = notifGui

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = Color3.fromRGB(239, 68, 68)
        cardStroke.Thickness = 1.8
        cardStroke.Transparency = 0.1
        cardStroke.Parent = card

        local logo = Instance.new("ImageLabel")
        logo.Size = UDim2.new(0, 48, 0, 48)
        logo.Position = UDim2.new(0, 10, 0.5, -24)
        logo.BackgroundTransparency = 1
        logo.Image = clanLogoAsset
        logo.Parent = card

        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(1, 0)
        logoCorner.Parent = logo

        local logoStroke = Instance.new("UIStroke")
        logoStroke.Color = Color3.fromRGB(245, 158, 11)
        logoStroke.Thickness = 1.2
        logoStroke.Parent = logo

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -72, 0, 22)
        titleLbl.Position = UDim2.new(0, 68, 0, 10)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card

        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -72, 0, 30)
        descLbl.Position = UDim2.new(0, 68, 0, 32)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = message
        descLbl.TextColor3 = Color3.fromRGB(209, 213, 219)
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 11
        descLbl.TextWrapped = true
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.Parent = card

        local TweenService = game:GetService("TweenService")
        local tweenIn = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -325, 0, 70)
        })
        tweenIn:Play()

        task.delay(duration, function()
            if card and card.Parent then
                local tweenOut = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(1, 20, 0, 70),
                    BackgroundTransparency = 1
                })
                tweenOut:Play()
                tweenOut.Completed:Connect(function()
                    card:Destroy()
                end)
            end
        end)
    end)
end

-- ════════════════════════════════════════════════════════════
--  💎 ANGUSHUB X HUNTER — MODERN IN-GAME CLIENT GUI v4.3
--  🎨 UI ล้ำสมัยที่สุด พร้อมปุ่มโลโก้ลอยเปิด-ปิด (Draggable Logo Toggle)
--  ⚡ รองรับทั้งมือถือ (Touch) และคอมพิวเตอร์ (PC / Keybind) 100%
-- ════════════════════════════════════════════════════════════

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local function formatCommas(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function getBountyRank(b)
    b = tonumber(b) or 0
    if b >= 30000000 then return "👑 ราชาโจรสลัด (Pirate King)"
    elseif b >= 20000000 then return "🔥 4 จักรพรรดิ (Yonko)"
    elseif b >= 10000000 then return "⚡ แม่ทัพใหญ่ (Fleet Master)"
    elseif b >= 5000000 then return "☠️ ยอดนักล่า (Elite Hunter)"
    elseif b >= 2500000 then return "⚔️ โจรสลัดชื่อดัง"
    else return "🏴‍☠️ กะลาสีมือใหม่"
    end
end

local function copyToClipboard(text, msg)
    local setclip = setclipboard or (syn and syn.set_clipboard) or (Clipboard and Clipboard.set)
    if setclip then
        setclip(text)
        showClanNotification("📋 AngusHub x Hunter", msg or "คัดลอกลง Clipboard สำเร็จแล้ว!", 3)
    else
        showClanNotification("📋 AngusHub x Hunter", text, 5)
    end
end

-- ════════════════════════════════════════════════════════════
--  ⚙️ MOVEMENT & PLAYER STATE
-- ════════════════════════════════════════════════════════════
local customSpeed = 16
local customJump = 50
local infJumpActive = false
local noclipActive = false
local antiAfkActive = true

local function applySpeedAndJump()
    pcall(function()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if customSpeed > 16 then hum.WalkSpeed = customSpeed end
            if customJump > 50 then hum.JumpPower = customJump end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if customSpeed > 16 or customJump > 50 then
            applySpeedAndJump()
        end
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.6)
    applySpeedAndJump()
end)

UserInputService.JumpRequest:Connect(function()
    if infJumpActive then
        pcall(function()
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if noclipActive then
        pcall(function()
            if LP.Character then
                for _, part in ipairs(LP.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end)

pcall(function()
    LP.Idled:Connect(function()
        if antiAfkActive then
            local vu = game:GetService("VirtualUser")
            if vu then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end
        end
    end)
end)

-- ════════════════════════════════════════════════════════════
--  👁️ VISUALS & ESP LOGIC
-- ════════════════════════════════════════════════════════════
local playerEspActive = false
local fruitEspActive = false
local chestEspActive = false
local fullBrightActive = false

local trackedChestBills = {}
local trackedFruitBills = {}

local function clearPlayerESP()
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("AngusHighlight")
                if hl then hl:Destroy() end
                local b = p.Character:FindFirstChild("AngusBill")
                if b then b:Destroy() end
            end
        end
    end)
end

local function clearFruitESP()
    pcall(function()
        for _, b in ipairs(trackedFruitBills) do
            if b and b.Parent then b:Destroy() end
        end
        table.clear(trackedFruitBills)
    end)
end

local function clearChestESP()
    pcall(function()
        for _, b in ipairs(trackedChestBills) do
            if b and b.Parent then b:Destroy() end
        end
        table.clear(trackedChestBills)
    end)
end

local originalAmbient = Lighting.Ambient
local originalBrightness = Lighting.Brightness
local originalFogEnd = Lighting.FogEnd
local originalGlobalShadows = Lighting.GlobalShadows
local originalClockTime = Lighting.ClockTime

local function setFullBright(state)
    fullBrightActive = state
    pcall(function()
        if state then
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.Brightness = 2
            Lighting.FogEnd = 1e6
            Lighting.GlobalShadows = false
            Lighting.ClockTime = 14
        else
            Lighting.Ambient = originalAmbient
            Lighting.Brightness = originalBrightness
            Lighting.FogEnd = originalFogEnd
            Lighting.GlobalShadows = originalGlobalShadows
            Lighting.ClockTime = originalClockTime
        end
    end)
end

local function boostFPS()
    pcall(function()
        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
        end
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("MeshPart") then
                v.Material = Enum.Material.SmoothPlastic
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 0.5
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v.Lifetime = NumberRange.new(0)
            end
        end
        showClanNotification("🚀 AngusHub FPS Boost", "เพิ่มความลื่นสำเร็จ! ลดกราฟิกและเอฟเฟกต์แล้ว", 4)
    end)
end

-- ESP Background Loop (Ultra-efficient: sleeps when disabled, zero main-thread lag)
local lastChestScan = 0
task.spawn(function()
    while true do
        task.wait(0.6)
        if getgenv().ANGUSHUB_SESSION_ID ~= CURRENT_SESSION_ID then break end

        -- หากไม่ได้เปิด ESP ใดๆ เลย ให้หลับและไม่ทำงานเบื้องหลัง 100% (Zero CPU usage)
        if not (playerEspActive or fruitEspActive or chestEspActive) then
            task.wait(1.5)
            continue
        end

        pcall(function()
            local myPos = (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")) and LP.Character.HumanoidRootPart.Position or Vector3.new()

            -- 1) Player ESP
            if playerEspActive then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") then
                        local char = p.Character
                        local hrp = char.HumanoidRootPart
                        local hum = char.Humanoid

                        local hl = char:FindFirstChild("AngusHighlight")
                        if not hl then
                            hl = Instance.new("Highlight")
                            hl.Name = "AngusHighlight"
                            hl.FillColor = (p.Team and p.Team.Name == "Marines") and Color3.fromRGB(59, 130, 246) or Color3.fromRGB(239, 68, 68)
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = 0.55
                            hl.OutlineTransparency = 0
                            hl.Adornee = char
                            hl.Parent = char
                        end

                        local bill = char:FindFirstChild("AngusBill")
                        if not bill then
                            bill = Instance.new("BillboardGui")
                            bill.Name = "AngusBill"
                            bill.Size = UDim2.new(0, 150, 0, 36)
                            bill.StudsOffset = Vector3.new(0, 3.4, 0)
                            bill.AlwaysOnTop = true
                            bill.Adornee = char:FindFirstChild("Head") or hrp
                            bill.Parent = char

                            local nameLbl = Instance.new("TextLabel")
                            nameLbl.Name = "NameLbl"
                            nameLbl.Size = UDim2.new(1, 0, 0, 16)
                            nameLbl.BackgroundTransparency = 1
                            nameLbl.Font = Enum.Font.GothamBold
                            nameLbl.TextSize = 11
                            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                            nameLbl.Parent = bill

                            local distLbl = Instance.new("TextLabel")
                            distLbl.Name = "DistLbl"
                            distLbl.Size = UDim2.new(1, 0, 0, 14)
                            distLbl.Position = UDim2.new(0, 0, 0, 16)
                            distLbl.BackgroundTransparency = 1
                            distLbl.Font = Enum.Font.GothamMedium
                            distLbl.TextSize = 10
                            distLbl.TextColor3 = Color3.fromRGB(239, 68, 68)
                            distLbl.Parent = bill
                        end

                        if bill then
                            local dist = math.floor((hrp.Position - myPos).Magnitude)
                            local hpPct = math.clamp(math.floor((hum.Health / math.max(hum.MaxHealth, 1)) * 100), 0, 100)
                            local nLbl = bill:FindFirstChild("NameLbl")
                            if nLbl then nLbl.Text = p.DisplayName .. " (@" .. p.Name .. ")" end
                            local dLbl = bill:FindFirstChild("DistLbl")
                            if dLbl then dLbl.Text = tostring(dist) .. "m | HP: " .. tostring(hpPct) .. "%" end
                        end
                    end
                end
            end

            -- 2) Fruit ESP (ค้นหาเฉพาะ Object ผลปีศาจระดับบน ไม่สแกนทั้ง Map)
            if fruitEspActive then
                for _, obj in ipairs(workspace:GetChildren()) do
                    if (obj:IsA("Tool") or obj:IsA("Model")) and (obj.Name:find("Fruit") or (obj:FindFirstChild("Handle") and obj.Handle:FindFirstChild("Fruit"))) then
                        local part = obj:FindFirstChild("Handle") or obj:FindFirstChildOfClass("BasePart")
                        if part then
                            local b = obj:FindFirstChild("AngusFruitBill")
                            if not b then
                                b = Instance.new("BillboardGui")
                                b.Name = "AngusFruitBill"
                                b.Size = UDim2.new(0, 140, 0, 30)
                                b.StudsOffset = Vector3.new(0, 2.5, 0)
                                b.AlwaysOnTop = true
                                b.Adornee = part
                                b.Parent = obj
                                table.insert(trackedFruitBills, b)

                                local lbl = Instance.new("TextLabel")
                                lbl.Name = "Lbl"
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextSize = 11
                                lbl.TextColor3 = Color3.fromRGB(245, 158, 11)
                                lbl.Parent = b
                            end
                            local dist = math.floor((part.Position - myPos).Magnitude)
                            local lbl = b:FindFirstChild("Lbl")
                            if lbl then
                                lbl.Text = "🍎 " .. obj.Name .. "\n[" .. tostring(dist) .. "m]"
                            end
                        end
                    end
                end
            end

            -- 3) Chest ESP (สแกนกล่องสมบัติแบบ Throttled ทุก 8 วินาทีเท่านั้น)
            if chestEspActive then
                local now = tick()
                if now - lastChestScan > 8 then
                    lastChestScan = now
                    local searchRoot = workspace:FindFirstChild("ChestModels") or workspace
                    for _, obj in ipairs(searchRoot:GetChildren()) do
                        if obj.Name:find("Chest") then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildOfClass("BasePart")
                            if part and not part:FindFirstChild("AngusChestBill") then
                                local b = Instance.new("BillboardGui")
                                b.Name = "AngusChestBill"
                                b.Size = UDim2.new(0, 110, 0, 24)
                                b.StudsOffset = Vector3.new(0, 2, 0)
                                b.AlwaysOnTop = true
                                b.Adornee = part
                                b.Parent = part
                                table.insert(trackedChestBills, b)

                                local lbl = Instance.new("TextLabel")
                                lbl.Name = "Lbl"
                                lbl.Size = UDim2.new(1, 0, 1, 0)
                                lbl.BackgroundTransparency = 1
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextSize = 10
                                lbl.TextColor3 = Color3.fromRGB(16, 185, 129)
                                lbl.Parent = b
                            end
                        end
                    end
                end

                for i = #trackedChestBills, 1, -1 do
                    local b = trackedChestBills[i]
                    if b and b.Parent and b.Adornee then
                        local dist = math.floor((b.Adornee.Position - myPos).Magnitude)
                        local lbl = b:FindFirstChild("Lbl")
                        if lbl then
                            lbl.Text = "📦 " .. b.Parent.Name .. " [" .. tostring(dist) .. "m]"
                        end
                    else
                        table.remove(trackedChestBills, i)
                    end
                end
            end
        end)
    end
end)

-- ════════════════════════════════════════════════════════════
--  🌀 TELEPORTS & SERVER LOGIC
-- ════════════════════════════════════════════════════════════
local function teleportToPos(pos, name)
    pcall(function()
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            LP.Character.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            showClanNotification("🌀 AngusHub Teleport", "วาร์ปไป " .. (name or "จุดหมาย") .. " เรียบร้อยแล้ว!", 3)
        end
    end)
end

local function rejoinServer()
    pcall(function()
        showClanNotification("🔁 AngusHub Rejoin", "กำลังเชื่อมต่อเข้าเซิร์ฟเวอร์เดิม...", 3)
        task.wait(0.5)
        if #Players:GetPlayers() <= 1 then
            TeleportService:Teleport(game.PlaceId, LP)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end
    end)
end

local function serverHop()
    pcall(function()
        showClanNotification("🌐 AngusHub Server Hop", "กำลังค้นหาเซิร์ฟเวอร์ใหม่...", 4)
        local placeId = game.PlaceId
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = game:HttpGet(url)
        local data = HttpService:JSONDecode(res)
        if data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing and s.maxPlayers and s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(placeId, s.id, LP)
                    return
                end
            end
        end
        TeleportService:Teleport(placeId, LP)
    end)
end

-- ════════════════════════════════════════════════════════════
--  🏷️ WATERMARK BADGE (ป้ายสถิติมุมขวาบน)
-- ════════════════════════════════════════════════════════════
local function createWatermarkBadge()
    pcall(function()
        local parentGui = (gethui and gethui()) or game:GetService("CoreGui") or LP:WaitForChild("PlayerGui")
        if parentGui:FindFirstChild("AngusHubBadge") then
            parentGui.AngusHubBadge:Destroy()
        end

        local sg = Instance.new("ScreenGui")
        sg.Name = "AngusHubBadge"
        sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 185, 0, 42)
        frame.Position = UDim2.new(1, -195, 0, 14)
        frame.BackgroundColor3 = Color3.fromRGB(14, 14, 26)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = sg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(239, 68, 68)
        stroke.Thickness = 1.4
        stroke.Transparency = 0.2
        stroke.Parent = frame

        local logoImg = Instance.new("ImageLabel")
        logoImg.Size = UDim2.new(0, 32, 0, 32)
        logoImg.Position = UDim2.new(0, 6, 0.5, -16)
        logoImg.BackgroundTransparency = 1
        logoImg.Image = clanLogoAsset
        logoImg.Parent = frame

        local imgCorner = Instance.new("UICorner")
        imgCorner.CornerRadius = UDim.new(1, 0)
        imgCorner.Parent = logoImg

        local t1 = Instance.new("TextLabel")
        t1.Size = UDim2.new(1, -44, 0, 18)
        t1.Position = UDim2.new(0, 44, 0, 4)
        t1.BackgroundTransparency = 1
        t1.Text = "AngusHub x Hunter"
        t1.TextColor3 = Color3.fromRGB(255, 255, 255)
        t1.Font = Enum.Font.GothamBold
        t1.TextSize = 11
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.Parent = frame

        local t2 = Instance.new("TextLabel")
        t2.Name = "LiveLabel"
        t2.Size = UDim2.new(1, -44, 0, 16)
        t2.Position = UDim2.new(0, 44, 0, 20)
        t2.BackgroundTransparency = 1
        t2.Text = "🟢 Live · Tracker v4.3"
        t2.TextColor3 = Color3.fromRGB(16, 185, 129)
        t2.Font = Enum.Font.GothamMedium
        t2.TextSize = 10
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.Parent = frame

        sg.Parent = parentGui
    end)
end

-- ════════════════════════════════════════════════════════════
--  🖥️ ANGUSHUB MAIN GUI & FLOATING TOGGLE LOGO
-- ════════════════════════════════════════════════════════════
local function createCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function createStroke(parent, color, thickness, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(239, 68, 68)
    s.Thickness = thickness or 1
    s.Transparency = trans or 0
    s.Parent = parent
    return s
end

local function makeDraggable(dragHandle, frameToMove)
    frameToMove = frameToMove or dragHandle
    local dragging = false
    local dragInput, mousePos, framePos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = frameToMove.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frameToMove.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

local function createToggle(parent, title, desc, defaultState, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
    row.BorderSizePixel = 0
    row.Parent = parent

    createCorner(row, 8)
    createStroke(row, Color3.fromRGB(38, 42, 60), 1, 0.4)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -65, 0, 20)
    titleLbl.Position = UDim2.new(0, 10, 0, 3)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = Color3.fromRGB(243, 244, 246)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -65, 0, 14)
    descLbl.Position = UDim2.new(0, 10, 0, 21)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = desc or ""
    descLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 9
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.Parent = row

    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(0, 42, 0, 22)
    switchBtn.Position = UDim2.new(1, -50, 0.5, -11)
    switchBtn.BackgroundColor3 = defaultState and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(42, 45, 62)
    switchBtn.Text = ""
    switchBtn.AutoButtonColor = false
    switchBtn.Parent = row

    createCorner(switchBtn, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switchBtn

    createCorner(knob, 8)

    local state = defaultState

    local function updateView(animate)
        local targetColor = state and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(42, 45, 62)
        local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        if animate then
            TweenService:Create(switchBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = targetPos}):Play()
        else
            switchBtn.BackgroundColor3 = targetColor
            knob.Position = targetPos
        end
    end

    switchBtn.MouseButton1Click:Connect(function()
        state = not state
        updateView(true)
        pcall(callback, state)
    end)

    return {
        SetState = function(newState)
            state = newState
            updateView(true)
            pcall(callback, state)
        end,
        GetState = function() return state end,
        Frame = row
    }
end

local function createButton(parent, text, bgColor, textColor, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = bgColor or Color3.fromRGB(239, 68, 68)
    btn.Text = text
    btn.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Parent = parent

    createCorner(btn, 8)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        local origSize = btn.Size
        TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 2, origSize.Y.Scale, origSize.Y.Offset - 2)}):Play()
        task.delay(0.08, function()
            if btn and btn.Parent then
                TweenService:Create(btn, TweenInfo.new(0.08), {Size = origSize}):Play()
            end
        end)
        pcall(callback)
    end)

    return btn
end

local function buildAngusHubUI()
    local parentGui = (gethui and gethui()) or game:GetService("CoreGui") or LP:WaitForChild("PlayerGui")

    -- Clean old instances
    if parentGui:FindFirstChild("AngusHubMainGui") then parentGui.AngusHubMainGui:Destroy() end
    if parentGui:FindFirstChild("AngusHubToggleGui") then parentGui.AngusHubToggleGui:Destroy() end

    -- ════════════════════════════════════════════════════════════
    -- 1) FLOATING LOGO TOGGLE GUI (ปุ่มเปิด-ปิดรูปโลโก้ค่าย)
    -- ════════════════════════════════════════════════════════════
    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name = "AngusHubToggleGui"
    toggleGui.ResetOnSpawn = false
    toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local floatBtn = Instance.new("ImageButton")
    floatBtn.Name = "FloatingLogoBtn"
    floatBtn.Size = UDim2.new(0, 52, 0, 52)
    floatBtn.Position = UDim2.new(0, 20, 0.42, 0)
    floatBtn.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    floatBtn.BorderSizePixel = 0
    floatBtn.AutoButtonColor = false
    floatBtn.Parent = toggleGui

    createCorner(floatBtn, 26)
    local floatStroke = createStroke(floatBtn, Color3.fromRGB(239, 68, 68), 2.2, 0)

    local floatLogo = Instance.new("ImageLabel")
    floatLogo.Size = UDim2.new(1, -6, 1, -6)
    floatLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
    floatLogo.AnchorPoint = Vector2.new(0.5, 0.5)
    floatLogo.BackgroundTransparency = 1
    floatLogo.Image = clanLogoAsset
    floatLogo.Parent = floatBtn

    createCorner(floatLogo, 23)

    -- Glow pulse animation for floating logo button
    task.spawn(function()
        while floatBtn and floatBtn.Parent do
            TweenService:Create(floatStroke, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = Color3.fromRGB(245, 158, 11),
                Thickness = 2.8
            }):Play()
            task.wait(1.3)
            if not floatBtn or not floatBtn.Parent then break end
            TweenService:Create(floatStroke, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = Color3.fromRGB(239, 68, 68),
                Thickness = 2.0
            }):Play()
            task.wait(1.3)
        end
    end)

    -- ════════════════════════════════════════════════════════════
    -- 2) MAIN CLIENT GUI (หน้าต่างหลัก AngusHub x Hunter)
    -- ════════════════════════════════════════════════════════════
    local mainGui = Instance.new("ScreenGui")
    mainGui.Name = "AngusHubMainGui"
    mainGui.ResetOnSpawn = false
    mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local winW = math.min(540, math.max(320, vp.X - 30))
    local winH = math.min(350, math.max(260, vp.Y - 40))

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, winW, 0, winH)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(12, 13, 21)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Visible = true
    mainFrame.Parent = mainGui

    createCorner(mainFrame, 14)
    createStroke(mainFrame, Color3.fromRGB(239, 68, 68), 1.6, 0.15)

    -- Toggle Window function
    local isGuiOpen = true
    local function toggleMainGui(force)
        if force ~= nil then
            isGuiOpen = force
        else
            isGuiOpen = not isGuiOpen
        end

        if isGuiOpen then
            mainFrame.Visible = true
            mainFrame.Position = UDim2.new(0.5, 0, 0.52, 0)
            mainFrame.Size = UDim2.new(0, winW - 20, 0, winH - 20)
            TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, winW, 0, winH)
            }):Play()
        else
            local tw = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0.52, 0),
                Size = UDim2.new(0, winW - 20, 0, winH - 20)
            })
            tw:Play()
            tw.Completed:Connect(function()
                if not isGuiOpen then
                    mainFrame.Visible = false
                end
            end)
        end
    end

    -- Floating Logo Button: Touch & Mouse dragging + Tap Detection
    local isDraggingLogo = false
    local dragStart = nil
    local startPos = nil

    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingLogo = true
            dragStart = input.Position
            startPos = floatBtn.Position
        end
    end)

    floatBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isDraggingLogo then
                isDraggingLogo = false
                local dist = 0
                if dragStart then
                    dist = (Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(dragStart.X, dragStart.Y)).Magnitude
                end
                if dist < 8 then
                    toggleMainGui()
                end
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDraggingLogo and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            floatBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Top Header Bar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 44)
    topBar.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame

    makeDraggable(topBar, mainFrame)

    local topLogo = Instance.new("ImageLabel")
    topLogo.Size = UDim2.new(0, 30, 0, 30)
    topLogo.Position = UDim2.new(0, 10, 0.5, -15)
    topLogo.BackgroundTransparency = 1
    topLogo.Image = clanLogoAsset
    topLogo.Parent = topBar

    createCorner(topLogo, 15)
    createStroke(topLogo, Color3.fromRGB(245, 158, 11), 1.2, 0)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0, 200, 0, 22)
    titleLbl.Position = UDim2.new(0, 48, 0, 5)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "ANGUSHUB x HUNTER"
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = topBar

    local subTitleLbl = Instance.new("TextLabel")
    subTitleLbl.Size = UDim2.new(0, 160, 0, 14)
    subTitleLbl.Position = UDim2.new(0, 48, 0, 25)
    subTitleLbl.BackgroundTransparency = 1
    subTitleLbl.Text = "🟢 v4.3 • CLOUD LIVE TRACKER"
    subTitleLbl.TextColor3 = Color3.fromRGB(16, 185, 129)
    subTitleLbl.Font = Enum.Font.GothamMedium
    subTitleLbl.TextSize = 9
    subTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    subTitleLbl.Parent = topBar

    -- Close & Minimize Buttons
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = topBar

    createCorner(closeBtn, 6)

    closeBtn.MouseButton1Click:Connect(function()
        toggleMainGui(false)
        showClanNotification("💡 AngusHub", "กดที่ปุ่มโลโก้ หรือกด Right-Ctrl เพื่อเปิดเมนูอีกครั้ง", 3)
    end)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -66, 0.5, -14)
    minBtn.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 12
    minBtn.AutoButtonColor = false
    minBtn.BorderSizePixel = 0
    minBtn.Parent = topBar

    createCorner(minBtn, 6)

    minBtn.MouseButton1Click:Connect(function()
        toggleMainGui(false)
    end)

    -- Left Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 135, 1, -44)
    sidebar.Position = UDim2.new(0, 0, 0, 44)
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local sidebarDivider = Instance.new("Frame")
    sidebarDivider.Size = UDim2.new(0, 1, 1, 0)
    sidebarDivider.Position = UDim2.new(1, -1, 0, 0)
    sidebarDivider.BackgroundColor3 = Color3.fromRGB(30, 33, 48)
    sidebarDivider.BorderSizePixel = 0
    sidebarDivider.Parent = sidebar

    local tabListLayout = Instance.new("UIListLayout")
    tabListLayout.Padding = UDim.new(0, 4)
    tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabListLayout.Parent = sidebar

    local sidebarPad = Instance.new("UIPadding")
    sidebarPad.PaddingTop = UDim.new(0, 8)
    sidebarPad.PaddingLeft = UDim.new(0, 6)
    sidebarPad.PaddingRight = UDim.new(0, 6)
    sidebarPad.Parent = sidebar

    -- Right Content Pages Container
    local pagesContainer = Instance.new("Frame")
    pagesContainer.Name = "PagesContainer"
    pagesContainer.Size = UDim2.new(1, -143, 1, -50)
    pagesContainer.Position = UDim2.new(0, 140, 0, 47)
    pagesContainer.BackgroundTransparency = 1
    pagesContainer.Parent = mainFrame

    -- Tab definition & switching
    local tabData = {
        { name = "Tracker", label = "📊 แดชบอร์ด" },
        { name = "Movement", label = "⚡ เคลื่อนที่" },
        { name = "Visuals", label = "👁️ มองทะลุ" },
        { name = "Teleport", label = "🌀 วาร์ป & เซิร์ฟ" },
        { name = "Settings", label = "⚙️ ตั้งค่า & ค่าย" },
    }

    local tabButtons = {}
    local tabPages = {}
    local currentTab = "Tracker"

    local function switchTab(targetName)
        currentTab = targetName
        for name, page in pairs(tabPages) do
            if name == targetName then
                page.Visible = true
                page.CanvasPosition = Vector2.new(0, 0)
            else
                page.Visible = false
            end
        end

        for name, btn in pairs(tabButtons) do
            local ind = btn:FindFirstChild("Indicator")
            if name == targetName then
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(28, 22, 34)}):Play()
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                if ind then ind.Visible = true end
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(15, 17, 26)}):Play()
                btn.TextColor3 = Color3.fromRGB(156, 163, 175)
                if ind then ind.Visible = false end
            end
        end
    end

    -- Create Tab Pages and Sidebar Buttons
    for i, t in ipairs(tabData) do
        -- Button
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(28, 22, 34) or Color3.fromRGB(15, 17, 26)
        btn.Text = t.label
        btn.TextColor3 = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(156, 163, 175)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10.5
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.LayoutOrder = i
        btn.Parent = sidebar

        createCorner(btn, 8)

        local btnPad = Instance.new("UIPadding")
        btnPad.PaddingLeft = UDim.new(0, 10)
        btnPad.Parent = btn

        local ind = Instance.new("Frame")
        ind.Name = "Indicator"
        ind.Size = UDim2.new(0, 3, 0, 20)
        ind.Position = UDim2.new(0, -7, 0.5, -10)
        ind.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        ind.BorderSizePixel = 0
        ind.Visible = (i == 1)
        ind.Parent = btn

        createCorner(ind, 2)

        btn.MouseButton1Click:Connect(function()
            switchTab(t.name)
        end)

        tabButtons[t.name] = btn

        -- Page (ScrollingFrame)
        local page = Instance.new("ScrollingFrame")
        page.Name = t.name .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Color3.fromRGB(239, 68, 68)
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = (i == 1)
        page.Parent = pagesContainer

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 4)
        pagePad.PaddingBottom = UDim.new(0, 12)
        pagePad.PaddingLeft = UDim.new(0, 4)
        pagePad.PaddingRight = UDim.new(0, 8)
        pagePad.Parent = page

        tabPages[t.name] = page
    end

    -- ════════════════════════════════════════════════════════════
    -- 📊 TAB 1: TRACKER / DASHBOARD
    -- ════════════════════════════════════════════════════════════
    local p1 = tabPages["Tracker"]

    -- Top Live Sync Banner
    local syncBanner = Instance.new("Frame")
    syncBanner.Size = UDim2.new(1, 0, 0, 44)
    syncBanner.BackgroundColor3 = Color3.fromRGB(18, 21, 33)
    syncBanner.BorderSizePixel = 0
    syncBanner.Parent = p1

    createCorner(syncBanner, 8)
    createStroke(syncBanner, Color3.fromRGB(239, 68, 68), 1, 0.4)

    local syncDot = Instance.new("TextLabel")
    syncDot.Size = UDim2.new(0, 16, 0, 16)
    syncDot.Position = UDim2.new(0, 10, 0, 8)
    syncDot.BackgroundTransparency = 1
    syncDot.Text = "🟢"
    syncDot.TextSize = 10
    syncDot.Parent = syncBanner

    local syncTitle = Instance.new("TextLabel")
    syncTitle.Size = UDim2.new(1, -36, 0, 16)
    syncTitle.Position = UDim2.new(0, 30, 0, 7)
    syncTitle.BackgroundTransparency = 1
    syncTitle.Text = "AngusHub Cloud: เชื่อมต่อเรียลไทม์"
    syncTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    syncTitle.Font = Enum.Font.GothamBold
    syncTitle.TextSize = 11
    syncTitle.TextXAlignment = Enum.TextXAlignment.Left
    syncTitle.Parent = syncBanner

    local syncTimeLbl = Instance.new("TextLabel")
    syncTimeLbl.Size = UDim2.new(1, -36, 0, 14)
    syncTimeLbl.Position = UDim2.new(0, 30, 0, 23)
    syncTimeLbl.BackgroundTransparency = 1
    syncTimeLbl.Text = "ซิงค์ล่าสุด: กำลังโหลด..."
    syncTimeLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
    syncTimeLbl.Font = Enum.Font.Gotham
    syncTimeLbl.TextSize = 9
    syncTimeLbl.TextXAlignment = Enum.TextXAlignment.Left
    syncTimeLbl.Parent = syncBanner

    -- 6 Live Stats Cards (Grid Rows)
    local function createStatCard(parent, title, icon, defaultValue, accentColor)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.485, 0, 0, 52)
        card.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
        card.BorderSizePixel = 0
        card.Parent = parent

        createCorner(card, 8)
        createStroke(card, accentColor or Color3.fromRGB(38, 42, 60), 1, 0.4)

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -12, 0, 16)
        titleLbl.Position = UDim2.new(0, 10, 0, 6)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = icon .. " " .. title
        titleLbl.TextColor3 = Color3.fromRGB(156, 163, 175)
        titleLbl.Font = Enum.Font.GothamMedium
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, -12, 0, 22)
        valLbl.Position = UDim2.new(0, 10, 0, 22)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = defaultValue or "-"
        valLbl.TextColor3 = accentColor or Color3.fromRGB(255, 255, 255)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 12.5
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.Parent = card

        return valLbl
    end

    local row1 = Instance.new("Frame")
    row1.Size = UDim2.new(1, 0, 0, 52)
    row1.BackgroundTransparency = 1
    row1.Parent = p1

    local beliValLbl = createStatCard(row1, "เงินเบลี (Beli)", "💰", "฿ 0", Color3.fromRGB(245, 158, 11))
    beliValLbl.Parent.Position = UDim2.new(0, 0, 0, 0)

    local fragsValLbl = createStatCard(row1, "ชิ้นส่วนม่วง (Frags)", "💎", "💎 0", Color3.fromRGB(192, 132, 252))
    fragsValLbl.Parent.Position = UDim2.new(0.515, 0, 0, 0)

    local row2 = Instance.new("Frame")
    row2.Size = UDim2.new(1, 0, 0, 52)
    row2.BackgroundTransparency = 1
    row2.Parent = p1

    local bountyValLbl = createStatCard(row2, "ค่าหัว (Bounty / Honor)", "☠️", "☠️ 0", Color3.fromRGB(239, 68, 68))
    bountyValLbl.Parent.Position = UDim2.new(0, 0, 0, 0)

    local levelValLbl = createStatCard(row2, "เลเวล (Level)", "⚡", "⚡ 0 / 3000", Color3.fromRGB(56, 189, 248))
    levelValLbl.Parent.Position = UDim2.new(0.515, 0, 0, 0)

    local row3 = Instance.new("Frame")
    row3.Size = UDim2.new(1, 0, 0, 52)
    row3.BackgroundTransparency = 1
    row3.Parent = p1

    local fruitValLbl = createStatCard(row3, "ผลปีศาจ (Devil Fruit)", "🍎", "None", Color3.fromRGB(251, 146, 60))
    fruitValLbl.Parent.Position = UDim2.new(0, 0, 0, 0)

    local seaValLbl = createStatCard(row3, "ทะเล (Sea)", "🌊", "Blox Fruits", Color3.fromRGB(52, 211, 153))
    seaValLbl.Parent.Position = UDim2.new(0.515, 0, 0, 0)

    -- Force Sync & Copy Web URL Action Buttons
    createButton(p1, "⚡ ซิงค์ข้อมูลเดี๋ยวนี้ (Force Sync)", Color3.fromRGB(239, 68, 68), Color3.fromRGB(255, 255, 255), function()
        showClanNotification("🔄 AngusHub Sync", "กำลังดึงสถิติล่าสุดและส่งขึ้นเว็บ...", 2)
        local ok, msg, bVal = syncData()
        if ok then
            showClanNotification("✅ AngusHub Sync", "ซิงค์สำเร็จ! ค่าหัว: " .. tostring(bVal), 3)
        end
    end)

    createButton(p1, "🌐 คัดลอกลิงก์เว็บสถิติ (Copy Web URL)", Color3.fromRGB(30, 34, 52), Color3.fromRGB(243, 244, 246), function()
        copyToClipboard(SERVER_URL, "คัดลอกลิงก์เว็บสถิติ AngusHub สำเร็จ!")
    end)

    -- Tracker Callback Updater
    onTrackerDataUpdated = function()
        pcall(function()
            if beliValLbl then beliValLbl.Text = "฿ " .. formatCommas(lastBeli) end
            if fragsValLbl then fragsValLbl.Text = "💎 " .. formatCommas(lastFrags) end
            if bountyValLbl then bountyValLbl.Text = "☠️ " .. formatCommas(lastBounty) end
            if levelValLbl then levelValLbl.Text = "⚡ " .. tostring(lastLevel) .. " / 3000" end
            if fruitValLbl then fruitValLbl.Text = "🍎 " .. tostring(lastFruit) end
            if seaValLbl then seaValLbl.Text = "🌊 " .. tostring(lastSea) end
            if syncTimeLbl then syncTimeLbl.Text = "🟢 ซิงค์ล่าสุด: " .. tostring(lastSyncTime) .. " • ออนไลน์" end
        end)
    end

    -- Initial tracker text update
    onTrackerDataUpdated()

    -- ════════════════════════════════════════════════════════════
    -- ⚡ TAB 2: MOVEMENT & PLAYER
    -- ════════════════════════════════════════════════════════════
    local p2 = tabPages["Movement"]

    -- WalkSpeed Section
    local wsCard = Instance.new("Frame")
    wsCard.Size = UDim2.new(1, 0, 0, 56)
    wsCard.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
    wsCard.BorderSizePixel = 0
    wsCard.Parent = p2

    createCorner(wsCard, 8)
    createStroke(wsCard, Color3.fromRGB(38, 42, 60), 1, 0.4)

    local wsTitle = Instance.new("TextLabel")
    wsTitle.Size = UDim2.new(1, -20, 0, 16)
    wsTitle.Position = UDim2.new(0, 10, 0, 6)
    wsTitle.BackgroundTransparency = 1
    wsTitle.Text = "🏃 WalkSpeed (ความเร็วเดิน/วิ่ง):"
    wsTitle.TextColor3 = Color3.fromRGB(243, 244, 246)
    wsTitle.Font = Enum.Font.GothamBold
    wsTitle.TextSize = 11
    wsTitle.TextXAlignment = Enum.TextXAlignment.Left
    wsTitle.Parent = wsCard

    local wsSpeeds = {
        { label = "16 (ปกติ)", val = 16 },
        { label = "45 (ว่องไว)", val = 45 },
        { label = "80 (สปีด)", val = 80 },
        { label = "140 (วาป)", val = 140 }
    }
    for idx, s in ipairs(wsSpeeds) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.22, 0, 0, 24)
        b.Position = UDim2.new(0.02 + (idx - 1) * 0.245, 0, 0, 24)
        b.BackgroundColor3 = (customSpeed == s.val) and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(30, 33, 48)
        b.Text = s.label
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 9.5
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = wsCard

        createCorner(b, 6)

        b.MouseButton1Click:Connect(function()
            customSpeed = s.val
            applySpeedAndJump()
            for _, child in ipairs(wsCard:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = (child.Text == s.label) and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(30, 33, 48)
                end
            end
            showClanNotification("🏃 ความเร็ว", "ตั้งความเร็วเดินเป็น " .. tostring(s.val), 2)
        end)
    end

    -- JumpPower Section
    local jpCard = Instance.new("Frame")
    jpCard.Size = UDim2.new(1, 0, 0, 56)
    jpCard.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
    jpCard.BorderSizePixel = 0
    jpCard.Parent = p2

    createCorner(jpCard, 8)
    createStroke(jpCard, Color3.fromRGB(38, 42, 60), 1, 0.4)

    local jpTitle = Instance.new("TextLabel")
    jpTitle.Size = UDim2.new(1, -20, 0, 16)
    jpTitle.Position = UDim2.new(0, 10, 0, 6)
    jpTitle.BackgroundTransparency = 1
    jpTitle.Text = "🦘 JumpPower (พลังกระโดด):"
    jpTitle.TextColor3 = Color3.fromRGB(243, 244, 246)
    jpTitle.Font = Enum.Font.GothamBold
    jpTitle.TextSize = 11
    jpTitle.TextXAlignment = Enum.TextXAlignment.Left
    jpTitle.Parent = jpCard

    local jpPowers = {
        { label = "50 (ปกติ)", val = 50 },
        { label = "90 (กระโดดสูง)", val = 90 },
        { label = "160 (ลอยฟ้า)", val = 160 }
    }
    for idx, s in ipairs(jpPowers) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.3, 0, 0, 24)
        b.Position = UDim2.new(0.02 + (idx - 1) * 0.33, 0, 0, 24)
        b.BackgroundColor3 = (customJump == s.val) and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(30, 33, 48)
        b.Text = s.label
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 10
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = jpCard

        createCorner(b, 6)

        b.MouseButton1Click:Connect(function()
            customJump = s.val
            applySpeedAndJump()
            for _, child in ipairs(jpCard:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = (child.Text == s.label) and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(30, 33, 48)
                end
            end
            showClanNotification("🦘 กระโดด", "ตั้งพลังกระโดดเป็น " .. tostring(s.val), 2)
        end)
    end

    -- Infinite Jump
    createToggle(p2, "🚀 Infinite Jump (กระโดดไม่จำกัด)", "กดกระโดดกลางอากาศได้เรื่อยๆ ไม่มีตก", false, function(st)
        infJumpActive = st
    end)

    -- NoClip
    createToggle(p2, "👻 NoClip (เดินทะลุกำแพง)", "เดินทะลุกำแพง สิ่งก่อสร้าง และสิ่งกีดขวาง", false, function(st)
        noclipActive = st
    end)

    -- Anti-AFK
    createToggle(p2, "🛡️ Anti-AFK (กันหลุด 20 นาที)", "ป้องกันเกมเตะอัตโนมัติเมื่อยืนอยู่นิ่ง", true, function(st)
        antiAfkActive = st
    end)

    -- ════════════════════════════════════════════════════════════
    -- 👁️ TAB 3: VISUALS & ESP
    -- ════════════════════════════════════════════════════════════
    local p3 = tabPages["Visuals"]

    createToggle(p3, "👤 Player ESP (มองผู้เล่นทะลุกำแพง)", "แสดงกล่องเรืองแสง ชื่อ ระยะห่าง และเลือด", false, function(st)
        playerEspActive = st
        if not st then clearPlayerESP() end
    end)

    createToggle(p3, "🍇 Fruit ESP (มองผลปีศาจในแมพ)", "แสดงชื่อและตำแหน่งผลปีศาจที่ตกหรือเกิดในแมพ", false, function(st)
        fruitEspActive = st
        if not st then clearFruitESP() end
    end)

    createToggle(p3, "📦 Chest ESP (มองกล่องสมบัติ)", "แสดงตำแหน่งกล่องเงินและระยะห่าง", false, function(st)
        chestEspActive = st
        if not st then clearChestESP() end
    end)

    createToggle(p3, "💡 FullBright (ไฟสว่าง ปิดหมอก)", "เปิดแสงสว่างทั่วทั้งแมพ ไม่มีมืดหรือหมอก", false, function(st)
        setFullBright(st)
    end)

    createButton(p3, "🚀 บูสต์ FPS (ลดแลค ลื่นหัวแตก)", Color3.fromRGB(16, 185, 129), Color3.fromRGB(255, 255, 255), function()
        boostFPS()
    end)

    -- ════════════════════════════════════════════════════════════
    -- 🌀 TAB 4: TELEPORT & SERVER
    -- ════════════════════════════════════════════════════════════
    local p4 = tabPages["Teleport"]

    local tpPoints = {
        { name = "☕ คาเฟ่ (Cafe - Sea 2)", pos = Vector3.new(-380, 73, 298) },
        { name = "🏰 คฤหาสน์ (Mansion - Sea 3)", pos = Vector3.new(-12463, 375, -7551) },
        { name = "👑 ปราสาทกลางทะเล (Castle Sea - Sea 3)", pos = Vector3.new(-5085, 315, -3155) },
        { name = "🏙️ เกาะกลาง (Middle Town - Sea 1)", pos = Vector3.new(-655, 15, 1582) },
        { name = "🏴‍☠️ เกาะเริ่มโจรสลัด (Starter Island - Sea 1)", pos = Vector3.new(980, 16, 1428) }
    }

    for _, tp in ipairs(tpPoints) do
        createButton(p4, tp.name, Color3.fromRGB(24, 27, 42), Color3.fromRGB(243, 244, 246), function()
            teleportToPos(tp.pos, tp.name)
        end)
    end

    local srvRow = Instance.new("Frame")
    srvRow.Size = UDim2.new(1, 0, 0, 36)
    srvRow.BackgroundTransparency = 1
    srvRow.Parent = p4

    local rejBtn = createButton(srvRow, "🔁 รีจอยเซิร์ฟเดิม (Rejoin)", Color3.fromRGB(30, 34, 52), Color3.fromRGB(243, 244, 246), function()
        rejoinServer()
    end)
    rejBtn.Size = UDim2.new(0.485, 0, 1, 0)
    rejBtn.Position = UDim2.new(0, 0, 0, 0)

    local hopBtn = createButton(srvRow, "🌐 ย้ายเซิร์ฟ (Server Hop)", Color3.fromRGB(239, 68, 68), Color3.fromRGB(255, 255, 255), function()
        serverHop()
    end)
    hopBtn.Size = UDim2.new(0.485, 0, 1, 0)
    hopBtn.Position = UDim2.new(0.515, 0, 0, 0)

    -- ════════════════════════════════════════════════════════════
    -- ⚙️ TAB 5: SETTINGS & CLAN INFO
    -- ════════════════════════════════════════════════════════════
    local p5 = tabPages["Settings"]

    createToggle(p5, "🏷️ แสดงป้าย Watermark บนหน้าจอ", "แสดงหรือซ่อนป้ายโลโก้ AngusHub มุมขวาบน", true, function(st)
        local badge = parentGui:FindFirstChild("AngusHubBadge")
        if badge then badge.Enabled = st end
    end)

    createToggle(p5, "🔘 แสดงปุ่มโลโก้ลอย", "เปิดหรือซ่อนปุ่มวงกลมโลโก้สำหรับเปิดปิด UI", true, function(st)
        floatBtn.Visible = st
    end)

    -- Clan Info Card
    local clanCard = Instance.new("Frame")
    clanCard.Size = UDim2.new(1, 0, 0, 68)
    clanCard.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
    clanCard.BorderSizePixel = 0
    clanCard.Parent = p5

    createCorner(clanCard, 8)
    createStroke(clanCard, Color3.fromRGB(245, 158, 11), 1, 0.4)

    local cLogo = Instance.new("ImageLabel")
    cLogo.Size = UDim2.new(0, 44, 0, 44)
    cLogo.Position = UDim2.new(0, 10, 0.5, -22)
    cLogo.BackgroundTransparency = 1
    cLogo.Image = clanLogoAsset
    cLogo.Parent = clanCard

    createCorner(cLogo, 22)

    local cName = Instance.new("TextLabel")
    cName.Size = UDim2.new(1, -70, 0, 20)
    cName.Position = UDim2.new(0, 62, 0, 10)
    cName.BackgroundTransparency = 1
    cName.Text = "🔥 ค่าย AngusHub x Hunter"
    cName.TextColor3 = Color3.fromRGB(255, 255, 255)
    cName.Font = Enum.Font.GothamBold
    cName.TextSize = 12
    cName.TextXAlignment = Enum.TextXAlignment.Left
    cName.Parent = clanCard

    local cDesc = Instance.new("TextLabel")
    cDesc.Size = UDim2.new(1, -70, 0, 28)
    cDesc.Position = UDim2.new(0, 62, 0, 30)
    cDesc.BackgroundTransparency = 1
    cDesc.Text = "ค่ายล่าค่าหัวอันดับ 1 ในไทย • ระบบติดตามเรียลไทม์\nCloud Client v4.3 Official Release"
    cDesc.TextColor3 = Color3.fromRGB(156, 163, 175)
    cDesc.Font = Enum.Font.Gotham
    cDesc.TextSize = 10
    cDesc.TextXAlignment = Enum.TextXAlignment.Left
    cDesc.Parent = clanCard

    createButton(p5, "📋 คัดลอกลิงก์ Discord ค่าย AngusHub", Color3.fromRGB(30, 34, 52), Color3.fromRGB(243, 244, 246), function()
        copyToClipboard("https://discord.gg/angushub", "คัดลอกลิงก์ Discord ค่ายเรียบร้อยแล้ว!")
    end)

    createButton(p5, "❌ ปิดการทำงานสคริปต์ UI ทั้งหมด (Unload)", Color3.fromRGB(153, 27, 27), Color3.fromRGB(255, 255, 255), function()
        customSpeed = 16
        customJump = 50
        infJumpActive = false
        noclipActive = false
        playerEspActive = false
        fruitEspActive = false
        chestEspActive = false
        setFullBright(false)
        pcall(function()
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end)
        mainGui:Destroy()
        toggleGui:Destroy()
        showClanNotification("👋 AngusHub", "ปิดการทำงาน AngusHub In-Game UI สำเร็จ", 3)
    end)

    -- Keyboard shortcut (PC): RightControl or RightShift to toggle UI
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe then
            if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightShift then
                toggleMainGui()
            end
        end
    end)

    -- Attach to parentGui
    toggleGui.Parent = parentGui
    mainGui.Parent = parentGui
end

-- ════════════════════════════════════════════════════════════
--  🎯 HERMANOS HUB UI HOOK & REBRANDING ENGINE
--  ดักจับ UI ของ Hermanos Hub แล้วแปลงเป็นโลโก้และชื่อของ AngusHub x Hunter
--  รักษาฟังก์ชันการทำงานทุกอย่าง (PVP, Farm, Aimbot, Teleport) ไว้ 100% ครบถ้วน
-- ════════════════════════════════════════════════════════════
local function hookHermanosUI()
    local targetRoots = {}
    pcall(function()
        if gethui then table.insert(targetRoots, gethui()) end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        if cg and not table.find(targetRoots, cg) then table.insert(targetRoots, cg) end
    end)
    pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        if pg and not table.find(targetRoots, pg) then table.insert(targetRoots, pg) end
    end)

    local ourGuiNames = {
        ["AngusHubMainGui"] = true,
        ["AngusHubToggleGui"] = true,
        ["AngusHubBadge"] = true,
        ["AngusHubNotifGui"] = true,
        ["AngusHubESP"] = true
    }

    local robloxCoreNames = {
        ["RobloxGui"] = true,
        ["TopBarApp"] = true,
        ["PurchasePrompt"] = true,
        ["RobloxPromptGui"] = true,
        ["CoreScriptLocalization"] = true,
        ["DevConsoleMaster"] = true
    }

    local hookedElements = {}

    local function patchElement(elem)
        if not elem or not elem.Parent then return end
        if hookedElements[elem] then return end

        -- ข้าม UI ของ AngusHub เองและ UI มาตรฐานของ Roblox
        local screenGui = elem:FindFirstAncestorOfClass("ScreenGui")
        if screenGui and (ourGuiNames[screenGui.Name] or robloxCoreNames[screenGui.Name]) then
            return
        end

        -- 1) ดักจับข้อความที่เป็นชื่อค่าย Hermanos แล้วเปลี่ยนเป็น AngusHub x Hunter
        if elem:IsA("TextLabel") or elem:IsA("TextButton") or elem:IsA("TextBox") then
            local txt = elem.Text
            if txt and (txt:find("Hermanos") or txt:find("HERMANOS") or txt:find("hermanos")) then
                hookedElements[elem] = true
                local function applyText()
                    local t = elem.Text
                    if t:find("Hermanos") or t:find("HERMANOS") or t:find("hermanos") then
                        local newT = t:gsub("Hermanos%s*Hub", "AngusHub x Hunter")
                                      :gsub("HERMANOS%s*HUB", "ANGUSHUB x HUNTER")
                                      :gsub("hermanos%s*hub", "angushub x hunter")
                                      :gsub("Hermanos", "AngusHub")
                                      :gsub("HERMANOS", "ANGUSHUB")
                                      :gsub("hermanos", "angushub")
                        elem.Text = newT
                    end
                end
                applyText()
                elem:GetPropertyChangedSignal("Text"):Connect(applyText)
            end
        end

        -- 2) ดักจับโลโก้ของ Hermanos (ทั้งในแถบด้านบน ป้าย Watermark และปุ่มเปิด-ปิดลอย)
        if elem:IsA("ImageLabel") or elem:IsA("ImageButton") then
            local n = elem.Name:lower()
            local p = elem.Parent
            local parentName = p and p.Name:lower() or ""

            local isHermanosRelated = false
            if screenGui and (screenGui.Name:lower():find("hermanos") or screenGui.Name:lower():find("hub")) then
                isHermanosRelated = true
            end

            if not isHermanosRelated and p then
                for _, sibling in ipairs(p:GetChildren()) do
                    if (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) and sibling.Text:lower():find("hermanos") then
                        isHermanosRelated = true
                        break
                    end
                end
            end

            -- แยกแยะว่าไม่ใช่ไอคอนเมนูย่อย (เช่น ดาบ หรือ ผลไม้) แต่เป็นตัวโลโก้หลักหรือปุ่มลอย
            local isTabIcon = (n:find("tab") or parentName:find("tab") or parentName:find("sidebar")) and not (n:find("logo") or n:find("icon") or parentName:find("topbar"))
            local isLogoCandidate = (
                n:find("logo") or n:find("icon") or n:find("hub") or n:find("avatar") or
                parentName:find("logo") or parentName:find("topbar") or parentName:find("header") or
                parentName:find("toggle") or parentName:find("float") or parentName:find("button") or
                n:find("toggle") or n:find("float")
            )

            if not isTabIcon and (isHermanosRelated or isLogoCandidate) then
                local w = elem.AbsoluteSize.X > 0 and elem.AbsoluteSize.X or elem.Size.X.Offset
                local h = elem.AbsoluteSize.Y > 0 and elem.AbsoluteSize.Y or elem.Size.Y.Offset
                if (w >= 16 and w <= 100) or isLogoCandidate then
                    hookedElements[elem] = true
                    local function applyLogo()
                        if elem.Image ~= clanLogoAsset then
                            elem.Image = clanLogoAsset
                            elem.ImageColor3 = Color3.fromRGB(255, 255, 255)
                        end
                    end
                    applyLogo()
                    elem:GetPropertyChangedSignal("Image"):Connect(applyLogo)
                end
            end
        end
    end

    local function inspectScreenGui(gui)
        if not gui or not gui:IsA("LayerCollector") then return end
        if ourGuiNames[gui.Name] or robloxCoreNames[gui.Name] then return end

        for _, d in ipairs(gui:GetDescendants()) do
            pcall(patchElement, d)
        end

        gui.DescendantAdded:Connect(function(d)
            pcall(patchElement, d)
        end)
    end

    -- สแกนเฉพาะ ScreenGui ใหม่ที่ถูกสร้างขึ้น (ประหยัด CPU 100% ไม่แลค ไม่กระตุก)
    for _, root in ipairs(targetRoots) do
        pcall(function()
            for _, child in ipairs(root:GetChildren()) do
                inspectScreenGui(child)
            end
            root.ChildAdded:Connect(function(child)
                inspectScreenGui(child)
            end)
        end)
    end
end

-- ════════════════════════════════════════════════════════════
--  🚀 STARTUP EXECUTION & INITIALIZATION
-- ════════════════════════════════════════════════════════════
-- 1) แสดง Watermark โลโก้ค่าย
createWatermarkBadge()

-- 2) สร้าง AngusHub In-Game UI และปุ่มโลโก้ลอย
pcall(buildAngusHubUI)

-- 3) ซิงค์ข้อมูลครั้งแรก (แจ้งเตือนเพียง 1 ครั้งเมื่อเชื่อมต่อสำเร็จ ป้องกันการสแปมแจ้งเตือน)
local ok, res, bVal, bSrc = syncData()
if ok then
    print("========================================")
    print("  🔥 AngusHub x Hunter Live Tracker v4.3")
    print("  ☠️ ค่าหัวจริง: " .. tostring(bVal) .. " (" .. tostring(bSrc) .. ")")
    print("  🚀 ซิงค์ข้อมูลเรียลไทม์ทุก 3 วินาที")
    print("  🌐 ดูข้อมูลที่: " .. SERVER_URL)
    print("========================================")
    showClanNotification("🔥 AngusHub x Hunter", "✅ เชื่อมต่อสำเร็จ! ค่าหัว: " .. tostring(bVal) .. "\nแตะที่ปุ่มโลโก้เพื่อเปิด/ปิดเมนู", 5)
else
    warn("❌ ซิงค์ครั้งแรกไม่สำเร็จ: " .. tostring(res))
    showClanNotification("🔥 AngusHub x Hunter", "⚡ โหลด Client v4.3 สำเร็จ! แตะปุ่มโลโก้เพื่อเปิดเมนู", 4)
end

-- 4) ลูปอัพเดตอัตโนมัติแบบเรียลไทม์ (Live Sync ทุก 3 วินาที)
task.spawn(function()
    while true do
        task.wait(3)
        if getgenv().ANGUSHUB_SESSION_ID ~= CURRENT_SESSION_ID then
            break -- สิ้นสุดลูปเก่าทันทีหากมีการรันรอบใหม่
        end
        pcall(syncData)
    end
end)

-- 5) ดักจับ UI ของ Hermanos Hub แล้วแปลงเป็นโลโก้และชื่อ AngusHub (ฟังก์ชันทำงานครบ 100%)
task.spawn(function()
    pcall(hookHermanosUI)
end)

-- 6) รันสคริปต์เสริม Hermanos Hub ควบคู่ (รันแค่ครั้งเดียว ป้องกันรันซ้ำซ้อนจนค้าง)
if not getgenv().HERMANOS_RUNNING then
    getgenv().HERMANOS_RUNNING = true
    task.spawn(function()
        pcall(function()
            getgenv().script_mode = "PVP"
            loadstring(game:HttpGet("https://raw.githubusercontent.com/hermanos-dev/hermanos-hub/refs/heads/main/Loader.lua"))()
        end)
    end)
end


