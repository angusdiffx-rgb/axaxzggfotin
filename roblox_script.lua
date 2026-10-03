-- ╔════════════════════════════════════════════════════════════╗
-- ║   🔥 AngusHub x Hunter — ค่ายโปรล่าค่าหัว Blox Fruits       ║
-- ║   ⚡ Realtime Live Tracker v4.2                            ║
-- ║   อัพเดต Beli (เงินเขียว), Fragments (เงินม่วง),             ║
-- ║   ค่าหัว (Bounty / Honor), เลเวล /3000 และไอเทมเรียลไทม์    ║
-- ║   ซิงค์เข้าเว็บอัตโนมัติทุก 3 วินาที ไม่ต้องรีเฟรชหน้าเว็บ      ║
-- ╚════════════════════════════════════════════════════════════╝

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- 🌐 เซิร์ฟเวอร์หลัก (AngusHub Cloud on Render)
local SERVER_URL = "https://angushubxhunter-n4sp.onrender.com"

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

    local jsonData = HttpService:JSONEncode(payload)

    local http_req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    local ok, res = pcall(function()
        if http_req then
            return http_req({
                Url = SERVER_URL .. "/api/inventory",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
        end
    end)

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

        local card = Instance.new("Frame")
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

-- ฟังก์ชันสร้าง Watermark โลโก้ค่ายแบบพรีเมียมลอยบนหน้าจอเกม (ลากย้ายตำแหน่งได้)
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
        t2.Text = "🟢 Live · PVP On"
        t2.TextColor3 = Color3.fromRGB(16, 185, 129)
        t2.Font = Enum.Font.GothamMedium
        t2.TextSize = 10
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.Parent = frame

        sg.Parent = parentGui
    end)
end

-- แจ้งเตือนเมื่อเริ่มต้นรันสคริปต์
showClanNotification("🔥 AngusHub x Hunter", "⚡ กำลังเชื่อมต่อระบบ Realtime Tracker v4.2...", 4)

-- ซิงค์ข้อมูลครั้งแรก
local success, response, bVal, bSrc = pcall(syncData)
if success then
    print("========================================")
    print("  🔥 AngusHub x Hunter Live Tracker v4.2")
    print("  ☠️ ค่าหัวจริง: " .. tostring(bVal) .. " (" .. tostring(bSrc) .. ")")
    print("  🚀 ซิงค์ข้อมูลเรียลไทม์ทุก 3 วินาที")
    print("  🌐 ดูข้อมูลที่: " .. SERVER_URL)
    print("========================================")

    -- แจ้งเตือนเมื่อเชื่อมต่อสำเร็จ พร้อมรูปโลโก้ค่าย
    showClanNotification("🔥 AngusHub x Hunter", "✅ เชื่อมต่อเรียลไทม์สำเร็จ! ค่าหัว: " .. tostring(bVal), 6)

    -- สร้าง Watermark โลโก้ค่ายลอยบนหน้าจอ
    createWatermarkBadge()
else
    warn("❌ ซิงค์ครั้งแรกไม่สำเร็จ: " .. tostring(response))
end

-- ลูปอัพเดตอัตโนมัติแบบเรียลไทม์ (Live Sync)
task.spawn(function()
    while true do
        task.wait(3)
        pcall(syncData)
    end
end)

-- ════════════════════════════════════════════════════════════
--  🚀 รัน Hermanos Hub ควบคู่กับ Tracker (Multi-Threaded)
--  ทำงานแบบแยก Thread (task.spawn) ไม่ขัดขวางและไม่ทำให้ Tracker สะดุด
-- ════════════════════════════════════════════════════════════
task.spawn(function()
    pcall(function()
        getgenv().script_mode = "PVP" -- PVP, FARM
        loadstring(game:HttpGet("https://raw.githubusercontent.com/hermanos-dev/hermanos-hub/refs/heads/main/Loader.lua"))()
    end)
end)

