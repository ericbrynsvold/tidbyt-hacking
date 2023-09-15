load("render.star", "render")
load("http.star", "http")

BASE_URL = "https://statsapi.mlb.com/api/"
STANDINGS_API = BASE_URL + "v1/standings?leagueId=103"

def main():
    return render.Root(
        child = render.Column(
            expanded=True,
            children = wc_teams()
        )
    )

def wc_teams():
    res = http.get(url = STANDINGS_API, ttl_seconds = 600)
    if res.status_code != 200:
        fail("Error in fetching mlb.com standings %d - %s" % (res.status_code, res.body()))
    
    divisions = res.json()["records"]
    alWestRecords = getDivisionRecords(divisions, "alwest")
    astrosRecords = getTeamRecords(alWestRecords, "HOU")
    rangersRecords = getTeamRecords(alWestRecords, "TEX")
    marinersRecords = getTeamRecords(alWestRecords, "SEA")
    alEastRecords = getDivisionRecords(divisions, "aleast")
    jaysRecords = getTeamRecords(alEastRecords, "TOR")

    rangers = {
        "team": "TEX",
        "color": "#003278",
        "wc": rangersRecords["wildCardGamesBack"],
        "div": rangersRecords["divisionGamesBack"],
        "wpct": rangersRecords["winningPercentage"]
    }

    astros = {
        "team": "HOU",
        "color": "#EB6E1F",
        "wc": astrosRecords["wildCardGamesBack"],
        "div": astrosRecords["divisionGamesBack"],
        "wpct": astrosRecords["winningPercentage"]
    }

    mariners = {
        "team": "SEA",
        "color": "#005C5C",
        "wc": marinersRecords["wildCardGamesBack"],
        "div": marinersRecords["divisionGamesBack"],
        "wpct": marinersRecords["winningPercentage"]
    }

    jays = {
        "team": "TOR",
        "color": "#134A8E",
        "wc": jaysRecords["wildCardGamesBack"],
        "div": jaysRecords["divisionGamesBack"],
        "wpct": jaysRecords["winningPercentage"]
    }

    teams = sorted([rangers, astros, mariners, jays], key=lambda d: d['wpct'], reverse=True)

    teamViews = map(lambda x: teamToBox(x), teams)

    return teamViews

def teamToBox(team):
    return render.Box(
        color = team["color"],
        height = 8,
        child = teamToText(team)
    )

def teamToText(team):
    wc = team["wc"]
    if (wc == "-"): wc = "----"
    elif (wc[0] != "+"): wc = "-{}".format(wc)

    division = team["div"]
    if (team["team"] == "TOR"): division = " X "
    if (division == "-"): division = "---"

    textColor = "#FFF"
    if (team["team"] == "TEX"): textColor = "#FF0"

    return render.Text(
        font = "5x8",
        content = "{} {} {}".format(team["team"], division, wc),
        color = textColor
    )

def getDivisionRecords(divisions, divisionSlug):
    code = divisionSlugToCode(divisionSlug)
    for division in divisions:
        if division["division"]["id"] == code:
            return division["teamRecords"]

def getTeamRecords(divisionRecords, teamSlug):
    code = teamSlugToCode(teamSlug)
    for team in divisionRecords:
        if team["team"]["id"] == code:
            return team
    
def divisionSlugToCode(divisionSlug):
    if divisionSlug == "alwest": return 200
    if divisionSlug == "aleast": return 201
    return 200

def teamSlugToCode(teamSlug):
    if teamSlug == "TOR": return 141
    if teamSlug == "TEX": return 140
    if teamSlug == "HOU": return 117
    if teamSlug == "SEA": return 136

def map(f, list):
    return [f(x) for x in list]