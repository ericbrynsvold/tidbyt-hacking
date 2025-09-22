load("render.star", "render")
load("encoding/base64.star", "base64")
load("humanize.star", "humanize")
load("http.star", "http")
load("encoding/json.star", "json")
load("time.star", "time")

RANGERS_ICON = base64.decode("iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAAgUlEQVQ4T2NkMKr4z0AhYIQZ8v9sO0lGMRpXwtWTbchBIUUGB8UIsEEohiBLgCRhrsMmTjtDQDYfuL8C7kR8LkFXC/cOtlDF5R10tTgNQY8t5Ngg2hB074D4sNgg2xBcBqBEMU3ChFDsIFs6BGIHPYrRkz7R3gGlYGRAVhQTWzYAAMRfaksi6lX2AAAAAElFTkSuQmCC")

BASE_MLB_URL = "https://statsapi.mlb.com/api/"
MLB_STANDINGS_API = BASE_MLB_URL + "v1/standings?leagueId=103"

FANGRAPHS_ODDS = "https://www.fangraphs.com/api/playoff-odds/odds?projectionMode=2&standingsType=div"

def main():
    mlb_response = http.get(url = MLB_STANDINGS_API)
    if mlb_response.status_code != 200:
        fail("Error in fetching mlb.com standings %d - %s" % (mlb_response.status_code, mlb_response.body()))
    mlbStandings = mlb_response.json()["records"]

    fg_response = http.get(FANGRAPHS_ODDS)
    if fg_response.status_code != 200:
        fail("Error in fetching Fangraphs odds %d - %s" % (fg_response.status_code, fg_response.body()))
    fangraphsJson = fg_response.json()
    rangersFangraphsJson = fangraphsGetTeam(fangraphsJson, "TEX")

    # default to standard logo + odds + division bars
    childrenToDisplay = [
        render.Box(
            color = "#003278",
            height = 26,
            child = render.Row(
                expanded = True,
                main_align = "start",
                cross_align = "center",
                children = [
                    render.Padding(
                        child = render.Image(src=RANGERS_ICON),
                        pad = 2
                    ),
                    standings(mlbStandings, rangersFangraphsJson)
                ]
            )
        ),
        division_chances_bars(fangraphsJson)
    ]

    poffOdds = rangersFangraphsJson["endData"]["poffTitle"]
    # Under 3% odds after the trading deadline, just call it
    if (poffOdds < 0.03 and time.now().month >= 8):
        alWestRecords = getAlWestMLB(mlbStandings)
        rangersRecords = getRangersMLB(alWestRecords)

        wins = int(rangersRecords["wins"])
        losses = int(rangersRecords["losses"])
        childrenToDisplay = [render.Box(
            color = "#003278",
            child = render.Row(
                expanded = True,
                main_align = "start",
                cross_align = "center",
                children = [
                    render.Padding(
                        child = render.Image(src = RANGERS_ICON),
                        pad = 2
                    ),
                    render.Column(
                        children = [
                            render.Row(children=[record_view(wins, losses)], main_align="center", expanded=True),
                            render.Row(children=[render.Text("FLAGS")], main_align="center", expanded=True),
                            render.Row(children=[render.Text("FLY")], main_align="center", expanded=True),
                            render.Row(children=[render.Text("FOREVER")], main_align="center", expanded=True)
                        ]
                    )
                ]
            )
        )]

    return render.Root(
        child = render.Box(
            color = "#000000",
            child = render.Column(
                expanded = True,
                main_align = "start",
                cross_align = "start",
                children = childrenToDisplay
            )
        )
    )

def standings(mlbStandingsJson, rangersFangraphsJson):
    alWestRecords = getAlWestMLB(mlbStandingsJson)
    rangersRecords = getRangersMLB(alWestRecords)

    wins = int(rangersRecords["wins"])
    losses = int(rangersRecords["losses"])
    divisionRank = int(rangersRecords["divisionRank"])
    gamesDiff = genGamesDiff(alWestRecords)

    wildCardRank = -1
    if "wildCardRank" in rangersRecords and gamesDiff != 0:
        wildCardRank = int(rangersRecords["wildCardRank"])

    views = [
        record_view(wins, losses),
        al_west_view(divisionRank, gamesDiff, wildCardRank),
        playoff_odds(rangersFangraphsJson)
    ]

    return render.Column(
        children = views
    )


def division_chances_bars(fangraphsJson):
    rangers = {
        "color": "#003278",
        "dpct": fangraphsGetTeam(fangraphsJson, "TEX")["endData"]["divTitle"]
    }
    astros = {
        "color": "#EB6E1F",
        "dpct": fangraphsGetTeam(fangraphsJson, "HOU")["endData"]["divTitle"]
    }
    angels = {
        "color": "#BA0021",
        "dpct": fangraphsGetTeam(fangraphsJson, "LAA")["endData"]["divTitle"]
    }
    mariners = {
        "color": "#005C5C",
        "dpct": fangraphsGetTeam(fangraphsJson, "SEA")["endData"]["divTitle"]
    }
    athletics = {
        "color": "#003831",
        "dpct": fangraphsGetTeam(fangraphsJson, "ATH")["endData"]["divTitle"]
    }

    teams = sorted([rangers, astros, angels, mariners, athletics], key=lambda d: d['dpct'], reverse=True)

    teamBars = map(lambda x: teamToBar(x), teams)
    
    return render.Column(
        expanded = True,
        main_align = "end",
        children = teamBars
    )

def teamToBar(team):
    maybeWidth = int(64 * team["dpct"])
    return render.Box(
        color = team["color"],
        height = 1,
        # clamp width to 1, because Box.width = 0 means fill the screen
        width = 1 if (maybeWidth == 0) else maybeWidth
    )

def record_view(wins, losses):
    return render.Text(content = "{}-{}".format(wins, losses), color = "#FFF")

def al_west_view(rank, gamesDiff, wildCardRank):
    if gamesDiff == 0:
        return render.Text("{} (-)".format(humanize.ordinal(1)))
    formatString = "{} (+{})" if (gamesDiff > 0) else "{} ({})"
    color = "#FFF" if (gamesDiff >= 0 or wildCardRank <= 3) else "#D3D3D3"
    return render.Text(content = formatString.format(humanize.ordinal(rank), gamesDiff), color = color)

def playoff_odds(rangersFangraphsJson):
    playoffOdds = rangersFangraphsJson["endData"]["poffTitle"] * 100
    formattedPlayoffOdds = humanize.float("#.#", playoffOdds)
    return render.Text("P: %s%%" % formattedPlayoffOdds)


def genGamesDiff(alWest):
    rangers = getRangersMLB(alWest)
    if rangers["divisionRank"] != "1":
        if rangers["divisionGamesBack"] == "-":
            return 0
        return float(rangers["divisionGamesBack"]) * -1
    smallestGamesBack = 162.0
    for rival in alWest:
        if rival["team"]["id"] != 140 and float(rival["divisionGamesBack"]) < smallestGamesBack:
            smallestGamesBack = float(rival["divisionGamesBack"])
    return float(smallestGamesBack)

def getAlWestMLB(divisions):
    for division in divisions:
        if division["division"]["id"] == 200:
            return division["teamRecords"]

def getRangersMLB(alWest):
    for team in alWest:
        if team["team"]["id"] == 140:
            return team

def fangraphsGetTeam(standings, slug):
    for team in standings:
        if team["abbName"] == slug:
            return team

def map(f, list):
    return [f(x) for x in list]