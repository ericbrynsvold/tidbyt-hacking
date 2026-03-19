load("render.star", "render")
load("http.star", "http")
load("time.star", "time")

RANGERS_TEAM_ID = 140
RANGERS_BLUE = "#003278"
BASE_MLB_URL = "https://statsapi.mlb.com/api/v1/"
STREAK_PX_PER_GAME = 2
MAX_STREAK_GAMES = 16
STREAK_BAR_WIDTH = 2
# Accent for Rangers text and date/time
ACCENT_LIGHT = "#B0D4FF"

def main():
    # Use a fixed timezone so "today" and "next game" selection are consistent
    # between CI rendering and local/dev rendering.
    now = time.now().in_location("America/Chicago")
    year = now.year
    # Fetch full season schedule for the team (one call)
    schedule_url = BASE_MLB_URL + "schedule?sportId=1&teamId=140&season=" + str(year) + "&hydrate=probablePitcher(person)"
    resp = http.get(schedule_url, ttl_seconds=300)
    if resp.status_code != 200:
        fail("Error fetching schedule " + str(resp.status_code) + " - " + resp.body())

    root = resp.json()
    if "dates" not in root:
        return render_no_data()

    today_str = pad_num(now.year, 4) + "-" + pad_num(now.month, 2) + "-" + pad_num(now.day, 2)
    next_game = find_next_game(root["dates"], today_str)
    streak_count, is_win_streak = compute_streak(root["dates"], today_str)

    return render.Root(
        child = render.Box(
            color = "#000000",
            child = render.Row(
                expanded = True,
                main_align = "start",
                cross_align = "stretch",
                children = [
                    streak_bar(streak_count, is_win_streak),
                    next_game_block(next_game),
                ],
            ),
        ),
    )

def find_next_game(dates_list, today_str):
    # dates_list is list of { "date": "YYYY-MM-DD", "games": [...] }
    for date_obj in dates_list:
        d = date_obj["date"]
        if d < today_str:
            continue
        for g in date_obj.get("games", []):
            status = g.get("status", {})
            state = status.get("abstractGameState", "")
            if state == "Final" or state == "Cancelled" or state == "Postponed":
                continue
            return g
    return None

def compute_streak(dates_list, today_str):
    # Collect all final games for Rangers up to and including today, sort newest first
    games = []
    for date_obj in dates_list:
        d = date_obj["date"]
        if d > today_str:
            continue
        for g in date_obj.get("games", []):
            status = g.get("status", {})
            if status.get("abstractGameState") != "Final":
                continue
            if g.get("isTie") == True:
                continue
            teams = g.get("teams", {})
            away = teams.get("away", {})
            home = teams.get("home", {})
            away_id = away.get("team", {}).get("id", 0)
            home_id = home.get("team", {}).get("id", 0)
            if away_id != RANGERS_TEAM_ID and home_id != RANGERS_TEAM_ID:
                continue
            rangers_won = (away_id == RANGERS_TEAM_ID and away.get("isWinner") == True) or (home_id == RANGERS_TEAM_ID and home.get("isWinner") == True)
            games.append({"date": d, "rangers_won": rangers_won})

    # Sort by date descending (most recent first)
    games = sorted(games, key=lambda x: x["date"], reverse=True)

    if len(games) == 0:
        return 0, True

    first_win = games[0]["rangers_won"]
    count = 0
    for g in games:
        if g["rangers_won"] != first_win:
            break
        count = count + 1

    return count, first_win

def next_game_block(game):
    if game == None:
        return render.Box(
            color = "#000000",
            child = render.Column(
                children = [
                    render.Text(font = "5x8", content = "No game scheduled", color = "#FFF"),
                ],
            ),
        )

    # Rangers brand color for text (used regardless of streak background).
    tex_color = RANGERS_BLUE

    teams = game.get("teams", {})
    away = teams.get("away", {})
    home = teams.get("home", {})
    away_team = away.get("team", {})
    home_team = home.get("team", {})
    away_id = away_team.get("id", 0)
    home_id = home_team.get("id", 0)
    if away_id == RANGERS_TEAM_ID:
        opp_name = short_team_name(home_team.get("name", ""))
        at_or_vs = "at "
    else:
        opp_name = short_team_name(away_team.get("name", ""))
        at_or_vs = "vs "

    # Line 1: TEX vs/at OPP with team colors
    line1 = render.Row(
        children = [
            render.Text(font = "5x8", content = "TEX ", color = tex_color),
            render.Text(font = "5x8", content = at_or_vs, color = "#FFF"),
            render.Text(font = "5x8", content = opp_name, color = team_text_color(opp_name)),
        ],
    )

    game_date = game.get("gameDate", "")
    official_date = game.get("officialDate", "")
    time_str = format_game_time(game_date)
    date_str = format_game_date(official_date)
    # Line 2: date / time (accent)
    # Line 2 stays pure white for readability across all opponents.
    line2 = render.Text(font = "5x8", content = date_str + " / " + time_str, color = "#FFFFFF")

    # Probable pitchers: first = Rangers, second = opponent; color by team
    if away_id == RANGERS_TEAM_ID:
        rangers_prob = away.get("probablePitcher")
        opp_prob = home.get("probablePitcher")
    else:
        rangers_prob = home.get("probablePitcher")
        opp_prob = away.get("probablePitcher")
    line3 = render.Text(font = "5x8", content = pitcher_last_name(rangers_prob), color = tex_color)
    line4 = render.Text(font = "5x8", content = pitcher_last_name(opp_prob), color = team_text_color(opp_name))

    lines = [line1, line2, line3, line4]

    return render.Box(
        color = "#000000",
        child = render.Column(
            children = lines,
        ),
    )

def pitcher_last_name(probable_pitcher):
    if probable_pitcher == None:
        return "TBD"
    full = probable_pitcher.get("fullName", "")
    if full == "":
        return "TBD"
    parts = full.split(" ")
    if len(parts) >= 2:
        return parts[-1]
    return full

def format_game_date(official_date):
    if official_date == "":
        return ""
    # "2025-03-25" -> "3/25"
    parts = official_date.split("-")
    if len(parts) < 3:
        return official_date
    month = int(parts[1])
    day = int(parts[2])
    return str(month) + "/" + str(day)

def pad_num(n, width):
    s = str(n)
    if width == 2 and n < 10:
        return "0" + s
    return s

def team_color(abbrev):
    # Team colors for matchup line and pitcher names
    colors = {
        "LAA": "#BA0021",
        "HOU": "#EB6E1F",
        "OAK": "#003831",
        "SEA": "#005C5C",
        "TEX": "#B0D4FF",
        "BAL": "#DF4601",
        "BOS": "#BD3039",
        "NYY": "#0C2340",
        "TB": "#092C5C",
        "TOR": "#134A8E",
        "CLE": "#0C2340",
        "CWS": "#27251F",
        "DET": "#0C2340",
        "KC": "#004687",
        "MIN": "#002B5C",
        "ATL": "#CE1141",
        "MIA": "#00A3E0",
        "NYM": "#002D72",
        "PHI": "#E81828",
        "WSH": "#AB0003",
        "CHC": "#0E3386",
        "CIN": "#C6011F",
        "MIL": "#0A2351",
        "PIT": "#27251F",
        "STL": "#C41E3A",
        "ARI": "#A71930",
        "COL": "#33006F",
        "LAD": "#005A9C",
        "SD": "#2F241D",
        "SF": "#FD5A1E",
    }
    if abbrev in colors:
        return colors[abbrev]
    return "#DDD"

MIN_LUMINANCE = 70

def hex_to_rgb(hex_color):
    if hex_color == None:
        return 255, 255, 255
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    return r, g, b

def hex_byte_to_two(n):
    # Starlark-friendly 0-255 -> 2 hex chars
    digits = "0123456789ABCDEF"
    hi = n // 16
    lo = n % 16
    return digits[hi] + digits[lo]

def rgb_to_hex(r, g, b):
    return "#" + hex_byte_to_two(r) + hex_byte_to_two(g) + hex_byte_to_two(b)

def luminance_num(r, g, b):
    # Uses lum ~= 0.2126*r + 0.7152*g + 0.0722*b, scaled by 10000.
    return 2126 * r + 7152 * g + 722 * b

def lighten_toward_white(hex_color, target_luminance):
    # If already bright enough, keep it.
    r, g, b = hex_to_rgb(hex_color)
    lum0 = luminance_num(r, g, b)  # scaled to /10000 later
    target_num = target_luminance * 10000
    white_num = 255 * 10000
    if lum0 >= target_num:
        return hex_color

    # Blend factor alpha computed in rational form:
    # lum(alpha) = (1-alpha)*lum0 + alpha*255  => alpha = (target - lum0)/(255 - lum0)
    # All in "scaled by 10000" space to avoid float math.
    a_num = target_num - lum0
    a_den = white_num - lum0
    # r_new = r + alpha*(255-r) => r_new = (r*a_den + a_num*(255-r))/a_den
    new_r = int((r * a_den + a_num * (255 - r)) / a_den)
    new_g = int((g * a_den + a_num * (255 - g)) / a_den)
    new_b = int((b * a_den + a_num * (255 - b)) / a_den)
    return rgb_to_hex(new_r, new_g, new_b)

def team_text_color(abbrev):
    # Preserve variety: if the team color is too dark on black, blend it toward white.
    base = team_color(abbrev)
    return lighten_toward_white(base, MIN_LUMINANCE)

def short_team_name(full_name):
    # Shorten for 64px display
    m = {
        "Angels": "LAA",
        "Astros": "HOU",
        "Athletics": "OAK",
        "Blue Jays": "TOR",
        "Guardians": "CLE",
        "Mariners": "SEA",
        "Rangers": "TEX",
        "Rays": "TB",
        "Red Sox": "BOS",
        "Royals": "KC",
        "Tigers": "DET",
        "Twins": "MIN",
        "White Sox": "CWS",
        "Yankees": "NYY",
        "Braves": "ATL",
        "Marlins": "MIA",
        "Mets": "NYM",
        "Phillies": "PHI",
        "Nationals": "WSH",
        "Cubs": "CHC",
        "Reds": "CIN",
        "Brewers": "MIL",
        "Pirates": "PIT",
        "Cardinals": "STL",
        "Diamondbacks": "ARI",
        "Rockies": "COL",
        "Dodgers": "LAD",
        "Padres": "SD",
        "Giants": "SF",
        "Orioles": "BAL",
    }
    for k, v in m.items():
        if k in full_name:
            return v
    # Fallback: first word or truncate
    parts = full_name.split(" ")
    if len(parts) >= 2:
        return parts[-1][:4]
    return full_name[:6]

def format_game_time(iso_str):
    if iso_str == "":
        return ""
    # "2025-03-25T18:35:00Z" -> "6:35p" or "Mar 25 6:35p"
    parts = iso_str.split("T")
    if len(parts) < 2:
        return parts[0]
    time_part = parts[1]
    hour_min = time_part.split(":")
    if len(hour_min) < 2:
        return time_part[:5]
    hour = int(hour_min[0])
    min_str = hour_min[1][:2]
    # Simple UTC to local-ish: assume Central (Rangers), subtract 5 or 6
    hour = hour - 5
    if hour < 0:
        hour = hour + 24
    if hour == 0:
        hour = 12
    elif hour > 12:
        hour = hour - 12
    return str(hour) + ":" + min_str + "p"

def streak_bar(streak_count, is_win_streak):
    # Vertical bar on the left: only the streak portion is green/red; the rest is black.
    # 32px-tall black column with green/red streak at the top.
    DISPLAY_HEIGHT = 32
    if streak_count <= 0:
        return render.Box(width = STREAK_BAR_WIDTH, height = DISPLAY_HEIGHT, color = "#000000")

    bar_height = streak_count * STREAK_PX_PER_GAME
    if bar_height > MAX_STREAK_GAMES * STREAK_PX_PER_GAME:
        bar_height = MAX_STREAK_GAMES * STREAK_PX_PER_GAME

    bar_color = "#00AA00" if is_win_streak else "#CC0000"
    remaining_height = DISPLAY_HEIGHT - bar_height
    if remaining_height < 0:
        remaining_height = 0

    return render.Box(
        width = STREAK_BAR_WIDTH,
        height = DISPLAY_HEIGHT,
        color = "#000000",
        child = render.Column(
            main_align = "start",
            cross_align = "start",
            children = [
                render.Box(width = STREAK_BAR_WIDTH, height = bar_height, color = bar_color),
                render.Box(width = STREAK_BAR_WIDTH, height = remaining_height, color = "#000000"),
            ],
        ),
    )

def render_no_data():
    return render.Root(
        child = render.Box(
            color = "#000000",
            child = render.Column(
                expanded = True,
                children = [
                    render.Box(
                        color = "#000000",
                        child = render.Column(
                            children = [
                                render.Text(font = "5x8", content = "No schedule", color = "#FFF"),
                            ],
                        ),
                    ),
                    render.Box(height = 1, width = 1, color = "#333333"),
                ],
            ),
        ),
    )
