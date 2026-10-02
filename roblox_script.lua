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
local SERVER_URL = "https://angushubxhunter.onrender.com"

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

local function syncData()
    local inv = {}

    -- 1) Backpack
    for _, item in pairs(LP.Backpack:GetChildren()) do
        if item:IsA("Tool") then
            local i = scanItem(item)
            i.equipped = false
            i.source = "Backpack"
            table.insert(inv, i)
        end
    end

    -- 2) Character (Equipped)
    if LP.Character then
        for _, item in pairs(LP.Character:GetChildren()) do
            if item:IsA("Tool") then
                local i = scanItem(item)
                i.equipped = true
                i.source = "Equipped"
                table.insert(inv, i)
            end
        end
    end

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

    local ok, res = pcall(function()
        return request({
            Url = SERVER_URL .. "/api/inventory",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
    end)

    return ok, res, bountyVal, bSource
end

-- ซิงค์ข้อมูลครั้งแรก
local success, response, bVal, bSrc = pcall(syncData)
if success then
    print("========================================")
    print("  🔥 AngusHub x Hunter Live Tracker v4.2")
    print("  ☠️ ค่าหัวจริง: " .. tostring(bVal) .. " (" .. tostring(bSrc) .. ")")
    print("  🚀 ซิงค์ข้อมูลเรียลไทม์ทุก 3 วินาที")
    print("  🌐 ดูข้อมูลที่: " .. SERVER_URL)
    print("========================================")
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

