"""
Roblox Tracker v4.1 — Realtime Blox Fruits Dashboard + Local Icons
- Local icon caching (100% reliable, zero broken images)
- Realtime stats: Beli, Fragments, Bounty, Level (/3000), Race, Fruit, Sea
- Auto item filter: Removes Tool, Awakening, Heightened Senses, and unclassified Other items
- Zero-reload live updates
"""
from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
import requests
import urllib.parse
from datetime import datetime
import json
import os
import threading
import time

app = Flask(__name__)
CORS(app)

STATIC_ICONS_DIR = os.path.join(os.path.dirname(__file__), "static", "item_icons")
os.makedirs(STATIC_ICONS_DIR, exist_ok=True)

# Blacklist of unwanted items per user request:
# 4) ไม่ต้องแสดง Tool Other
# 5) Awakening ไม่ต้องแสดง
# 6) Heightened Senses ไม่ต้องแสดง
BLACKLIST_ITEMS = {"tool", "awakening", "heightened senses", "other"}


def categorize_item(name):
    """Categorize item accurately based on Blox Fruits item names."""
    n = name.lower().strip()

    # Fruit keywords
    if any(w in n for w in [
        "fruit", "gas", "kitsune", "dragon", "dough", "buddha", "leopard", "t-rex", "mammoth",
        "venom", "shadow", "control", "spirit", "portal", "rumble", "blizzard", "gravity", "pain",
        "sound", "phoenix", "magma", "ghost", "quake", "light", "love", "spider", "rubber",
        "barrier", "dark", "sand", "ice", "falcon", "flame", "spike", "smoke", "bomb", "spring",
        "chop", "spin", "rocket"
    ]):
        return "Fruit"

    # Sword keywords
    if any(w in n for w in [
        "sword", "blade", "katana", "cutlass", "saber", "trident", "pole", "bisento", "yoru",
        "shisui", "wando", "saddi", "tushita", "yama", "scythe", "anchor", "buddy", "canvander",
        "dagger", "cane", "dual", "rengoku"
    ]):
        return "Sword"

    # Gun keywords
    if any(w in n for w in [
        "rifle", "gun", "pistol", "musket", "cannon", "flintlock", "kabucha", "guitar", "bow",
        "bazooka", "acidum", "slingshot"
    ]):
        return "Gun"

    # Fighting Style keywords
    if any(w in n for w in [
        "sanguine", "godhuman", "talon", "karate", "claw", "superhuman", "combat", "death step",
        "kung fu", "dark step", "electric", "art"
    ]):
        return "Fighting Style"

    # Accessory keywords
    if any(w in n for w in [
        "cap", "hat", "mask", "glasses", "coat", "scarf", "lei", "crown", "bandana", "ring",
        "helmet", "cape", "shield", "earrings", "pendant", "ribbon"
    ]):
        return "Accessory"

    return "Other"


def resolve_bloxfruits_image(name):
    """Resolve item image to a local PNG file served from /static/item_icons/."""
    if not name or name.lower().strip() in BLACKLIST_ITEMS:
        return ""

    clean = name.replace(" Fruit", "").replace("-Fruit", "").strip()
    c1 = clean.split("-")[0].strip() if "-" in clean else clean

    candidates = [
        name.replace(" ", "_") + ".png",
        clean.replace(" ", "_") + ".png",
        c1.replace(" ", "_") + ".png",
        clean.replace(" ", "_") + "_Fruit.png",
        c1.replace(" ", "_") + "_Fruit.png",
        clean.title().replace(" ", "_") + ".png",
        c1.title().replace(" ", "_") + ".png",
    ]

    # 1) Check local disk first
    for c in candidates:
        dest = os.path.join(STATIC_ICONS_DIR, c)
        if os.path.exists(dest) and os.path.getsize(dest) > 500:
            return f"/static/item_icons/{c}"

    # 2) If not on disk, fetch from Fandom API & save locally
    titles = "|".join(["File:" + c for c in candidates[:5]])
    try:
        api_url = f"https://bloxfruits.fandom.com/api.php?action=query&titles={urllib.parse.quote(titles)}&prop=imageinfo&iiprop=url&format=json"
        r = requests.get(api_url, headers={"User-Agent": "Mozilla/5.0"}, timeout=4)
        if r.status_code == 200:
            pages = r.json().get("query", {}).get("pages", {})
            for p in pages.values():
                info = p.get("imageinfo", [])
                if info and info[0].get("url"):
                    remote_url = info[0]["url"]
                    local_filename = p.get("title", "").replace("File:", "").replace(" ", "_")
                    dest = os.path.join(STATIC_ICONS_DIR, local_filename)
                    dl = requests.get(remote_url, headers={"User-Agent": "Mozilla/5.0"}, timeout=4)
                    if dl.status_code == 200 and len(dl.content) > 500:
                        with open(dest, "wb") as f:
                            f.write(dl.content)
                        return f"/static/item_icons/{local_filename}"
    except Exception as e:
        print(f"Error fetching image for {name}: {e}")

    return ""


# Category metadata
CATEGORIES = {
    "Fruit":          {"icon": "🍎", "color": "#a855f7", "label": "Fruits"},
    "Sword":          {"icon": "⚔️", "color": "#ef4444", "label": "Swords"},
    "Gun":            {"icon": "🔫", "color": "#f97316", "label": "Guns"},
    "Fighting Style": {"icon": "🥊", "color": "#ec4899", "label": "Fighting Styles"},
    "Accessory":      {"icon": "👑", "color": "#06b6d4", "label": "Accessories"},
}

tracked_players = {}
player_inventories = {}


def get_user_info(user_id):
    try:
        r = requests.get(f"https://users.roblox.com/v1/users/{user_id}", timeout=4)
        return r.json() if r.status_code == 200 else None
    except:
        return None


def get_presence(user_ids):
    try:
        r = requests.post("https://presence.roblox.com/v1/presence/users",
                          json={"userIds": user_ids}, timeout=4)
        return r.json().get("userPresences", []) if r.status_code == 200 else []
    except:
        return []


def get_avatar(user_id):
    try:
        r = requests.get(
            f"https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds={user_id}&size=150x150&format=Png&isCircular=false",
            timeout=4)
        if r.status_code == 200:
            d = r.json().get("data", [])
            if d and d[0].get("imageUrl"):
                return d[0]["imageUrl"]
    except:
        pass
    return ""


STATUS_MAP = {
    0: {"text": "OFFLINE", "th": "ออฟไลน์", "cls": "offline"},
    1: {"text": "ONLINE", "th": "ออนไลน์", "cls": "online"},
    2: {"text": "IN-GAME", "th": "กำลังเล่นเกม", "cls": "ingame"},
    3: {"text": "STUDIO", "th": "อยู่ใน Studio", "cls": "studio"},
}


@app.route("/")
def index():
    if tracked_players:
        ids = [int(uid) for uid in tracked_players]
        for p in get_presence(ids):
            uid = str(p.get("userId"))
            if uid in tracked_players:
                s = STATUS_MAP.get(p.get("userPresenceType", 0), STATUS_MAP[0])
                tracked_players[uid].update({
                    "presence": p.get("userPresenceType", 0),
                    "status": s["text"], "status_th": s["th"], "cls": s["cls"],
                    "location": p.get("lastLocation", ""),
                    "checked": datetime.now().strftime("%H:%M:%S"),
                })

    stats = {"total": len(tracked_players), "online": 0, "ingame": 0}
    for p in tracked_players.values():
        if p.get("presence", 0) > 0:
            stats["online"] += 1
        if p.get("presence", 0) == 2:
            stats["ingame"] += 1

    proto = request.headers.get("X-Forwarded-Proto", request.scheme)
    host = request.headers.get("X-Forwarded-Host", request.host)
    if "onrender.com" in host:
        proto = "https"
    current_host_url = f"{proto}://{host}".rstrip("/")

    return render_template("dashboard.html",
                           players=tracked_players,
                           inventories=player_inventories,
                           categories=CATEGORIES,
                           stats=stats,
                           current_host_url=current_host_url)


@app.route("/api/live_data")
def live_data():
    """Live JSON endpoint for real-time DOM updates without page refresh."""
    return jsonify({
        "players": tracked_players,
        "inventories": player_inventories,
        "timestamp": datetime.now().strftime("%H:%M:%S")
    })


@app.route("/api/track", methods=["POST"])
def track():
    d = request.json
    if not d or not d.get("user_id"):
        return jsonify({"error": "need user_id"}), 400
    uid = str(d["user_id"])
    pres = get_presence([int(uid)])
    p = pres[0] if pres else {}
    s = STATUS_MAP.get(p.get("userPresenceType", 0), STATUS_MAP[0])
    tracked_players[uid] = {
        "uid": uid, "name": d.get("username", "?"),
        "display": d.get("display_name", d.get("username", "?")),
        "presence": p.get("userPresenceType", 0),
        "status": s["text"], "status_th": s["th"], "cls": s["cls"],
        "location": p.get("lastLocation", ""),
        "avatar": get_avatar(uid),
        "checked": datetime.now().strftime("%H:%M:%S"),
    }
    return jsonify({"ok": True, "status": s["th"]})


@app.route("/api/check/<uid>")
def check(uid):
    info = get_user_info(uid)
    if not info:
        return jsonify({"error": "not found"}), 404
    pres = get_presence([int(uid)])
    p = pres[0] if pres else {}
    s = STATUS_MAP.get(p.get("userPresenceType", 0), STATUS_MAP[0])
    tracked_players[uid] = {
        "uid": uid, "name": info.get("name", "?"),
        "display": info.get("displayName", "?"),
        "presence": p.get("userPresenceType", 0),
        "status": s["text"], "status_th": s["th"], "cls": s["cls"],
        "location": p.get("lastLocation", ""),
        "avatar": get_avatar(uid),
        "checked": datetime.now().strftime("%H:%M:%S"),
    }
    return jsonify({"ok": True, "display": info.get("displayName"), "status": s["th"]})


@app.route("/api/inventory", methods=["POST"])
def receive_inventory():
    """Receive inventory + realtime stats from Roblox script."""
    d = request.json
    if not d or not d.get("user_id"):
        return jsonify({"error": "need user_id"}), 400

    uid = str(d["user_id"])
    items = d.get("inventory", [])

    # Process items — filter out blacklisted items & resolve local images
    processed = []
    for item in items:
        item_name = item.get("name", "").strip()
        name_lower = item_name.lower()

        # 4, 5, 6: Skip Tool, Awakening, Heightened Senses, and Other
        if name_lower in BLACKLIST_ITEMS:
            continue

        # Smart categorize
        cat = categorize_item(name_lower)
        if cat == "Other":
            # Per user request: 4 ไม่ต้องแสดง Tool Other
            continue

        img_url = resolve_bloxfruits_image(item_name)

        processed.append({
            "name": item_name,
            "category": cat,
            "equipped": item.get("equipped", False),
            "source": item.get("source", "Backpack"),
            "image": img_url,
            "tooltip": item.get("toolTip", ""),
        })

    # Group by category
    categorized = {}
    for item in processed:
        c = item["category"]
        if c not in categorized:
            categorized[c] = []
        categorized[c].append(item)

    # Blox Fruits player stats
    player_stats = d.get("stats", {})

    def to_int(v, default=0):
        try:
            if isinstance(v, (int, float)):
                return int(v)
            if isinstance(v, str):
                cleaned = v.replace(",", "").replace("$", "").replace("ƒ", "").strip()
                return int(float(cleaned))
        except:
            pass
        return default

    beli = to_int(d.get("beli", player_stats.get("beli", 0)))
    fragments = to_int(d.get("fragments", player_stats.get("fragments", 0)))
    bounty = to_int(d.get("bounty", player_stats.get("bounty", 0)))
    level = to_int(d.get("level", player_stats.get("level", 0)))
    max_level = 3000
    race = d.get("race", "Human")
    devil_fruit = d.get("devil_fruit", "None")
    sea = d.get("sea", "Blox Fruits")
    health = d.get("health", None)
    energy = d.get("energy", None)
    team = d.get("team", "Pirates")
    bounty_src = str(d.get("bounty_source", ""))
    is_marine = "marine" in team.lower() or "honor" in bounty_src.lower()
    bounty_label = "Honor (เกียรติยศ)" if is_marine else "Bounty (ค่าหัว)"
    bounty_icon = "⚓" if is_marine else "☠️"

    existing_inv = player_inventories.get(uid, {})

    # Preserve previous values ONLY if incoming is 0 AND previous was valid (not the old buggy 8000000)
    if bounty == 0 and existing_inv.get("bounty") and existing_inv.get("bounty") != 8000000:
        bounty = existing_inv.get("bounty")

    if beli == 0 and existing_inv.get("beli"):
        beli = existing_inv.get("beli")

    if fragments == 0 and existing_inv.get("fragments"):
        fragments = existing_inv.get("fragments")

    if level == 0 and existing_inv.get("level"):
        level = existing_inv.get("level")

    if (not race or race == "Human" or race == "Unknown") and existing_inv.get("race"):
        race = existing_inv.get("race")

    if (not devil_fruit or devil_fruit == "None") and existing_inv.get("devil_fruit"):
        devil_fruit = existing_inv.get("devil_fruit")

    if not processed and existing_inv.get("items"):
        processed = existing_inv.get("items")
        categorized = existing_inv.get("categorized", {})

    player_inventories[uid] = {
        "uid": uid,
        "username": d.get("username", "?"),
        "display_name": d.get("display_name", "?"),
        "game_name": d.get("game_name", "Blox Fruits"),
        "place_id": d.get("place_id", ""),
        "scan_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "items": processed,
        "item_list": processed,
        "categorized": categorized,
        "total": len(processed),
        # Live Stats
        "beli": beli,
        "fragments": fragments,
        "bounty": bounty,
        "bounty_label": bounty_label,
        "bounty_icon": bounty_icon,
        "team": team,
        "level": level,
        "max_level": max_level,
        "race": race,
        "devil_fruit": devil_fruit,
        "sea": sea,
        "health": health,
        "energy": energy,
    }

    # Ensure player in tracked_players
    if uid not in tracked_players:
        pres = get_presence([int(uid)])
        p = pres[0] if pres else {}
        s = STATUS_MAP.get(p.get("userPresenceType", 0), STATUS_MAP[0])
        tracked_players[uid] = {
            "uid": uid, "name": d.get("username", "?"),
            "display": d.get("display_name", "?"),
            "presence": p.get("userPresenceType", 0),
            "status": s["text"], "status_th": s["th"], "cls": s["cls"],
            "location": sea or p.get("lastLocation", ""),
            "avatar": get_avatar(uid),
            "checked": datetime.now().strftime("%H:%M:%S"),
        }
    else:
        tracked_players[uid]["location"] = sea or tracked_players[uid].get("location", "")
        tracked_players[uid]["checked"] = datetime.now().strftime("%H:%M:%S")

    return jsonify({
        "ok": True,
        "message": f"Updated {d.get('username')} ({len(processed)} items)",
        "total": len(processed),
        "beli": beli,
        "fragments": fragments,
        "bounty": bounty,
        "level": level
    })


@app.route("/api/remove/<uid>", methods=["DELETE"])
def remove(uid):
    tracked_players.pop(uid, None)
    player_inventories.pop(uid, None)
    return jsonify({"ok": True})


@app.route("/script.lua")
@app.route("/api/script")
def serve_script():
    """Serve the absolute latest roblox_script.lua directly for executors and web UI,
    automatically rewriting SERVER_URL to the actual current host (e.g. onrender.com)."""
    lua_path = os.path.join(os.path.dirname(__file__), "roblox_script.lua")
    if os.path.exists(lua_path):
        with open(lua_path, "r", encoding="utf-8") as f:
            code = f.read()

        proto = request.headers.get("X-Forwarded-Proto", request.scheme)
        host = request.headers.get("X-Forwarded-Host", request.host)
        if "onrender.com" in host:
            proto = "https"
        public_url = f"{proto}://{host}".rstrip("/")

        import re
        code = re.sub(r'SERVER_URL\s*=\s*"[^"]*"', f'SERVER_URL = "{public_url}"', code)

        from flask import Response
        return Response(code, mimetype="text/plain; charset=utf-8")
    return "print('Error: roblox_script.lua not found')", 404


@app.route("/ping")
@app.route("/healthz")
def ping_service():
    """Lightweight endpoint for Render keep-alive & external uptime monitors."""
    return jsonify({
        "status": "online",
        "service": "angushubxhunter",
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "keep_alive": True
    }), 200


def _render_keep_alive():
    """Background daemon that pings the Render service periodically to prevent idling."""
    # Wait 60 seconds after boot before first ping
    time.sleep(60)
    while True:
        urls_to_try = []
        ext_url = os.environ.get("RENDER_EXTERNAL_URL", "").strip()
        if ext_url:
            urls_to_try.append(ext_url)
        urls_to_try.extend([
            "https://angushubxhunter.onrender.com",
            "https://angushubxhubter.onrender.com"
        ])

        for base in urls_to_try:
            try:
                target = f"{base.rstrip('/')}/ping"
                r = requests.get(target, timeout=15)
                if r.status_code == 200:
                    print(f"[Keep-Alive] Pinged {target} -> 200 OK")
                    break
            except Exception:
                pass

        # Ping every 10 minutes (600s). Render idles at 15 minutes (900s).
        time.sleep(600)


# Start background keep-alive thread automatically
threading.Thread(target=_render_keep_alive, daemon=True, name="RenderKeepAliveThread").start()


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print()
    print("  ============================================")
    print("  Roblox Live Tracker v4.2 - Realtime Dashboard")
    print(f"  Dashboard: http://localhost:{port}")
    print(f"  Script URL: http://localhost:{port}/script.lua")
    print("  ============================================")
    print()
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
