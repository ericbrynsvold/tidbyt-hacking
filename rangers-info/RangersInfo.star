load("render.star", "render")
load("encoding/base64.star", "base64")
load("humanize.star", "humanize")
load("http.star", "http")
load("encoding/json.star", "json")

RANGERS_ICON = base64.decode("iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAAgUlEQVQ4T2NkMKr4z0AhYIQZ8v9sO0lGMRpXwtWTbchBIUUGB8UIsEEohiBLgCRhrsMmTjtDQDYfuL8C7kR8LkFXC/cOtlDF5R10tTgNQY8t5Ngg2hB074D4sNgg2xBcBqBEMU3ChFDsIFs6BGIHPYrRkz7R3gGlYGRAVhQTWzYAAMRfaksi6lX2AAAAAElFTkSuQmCC")
RANGERS_ICON_GOLD = base64.decode("iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAAgUlEQVQ4T2NkMKr4z0AhYIQZ8n9pB0lGMUZXwNWTbchBKwUGB8UIsEEohiBLgCRhrsMmTjtDQDYfuL8C7kR8LkFXC/cOtlDF5R10tTgNQY8t5Ngg2hB074D4sNgg2xBcBqBEMU3ChFDsIFs6BGIHPYrRkz7R3gGlYGRAVhQTWzYAAKEHakvpJC9lAAAAAElFTkSuQmCC")

BASE_URL = "https://statsapi.mlb.com/api/"
STANDINGS_API = BASE_URL + "v1/standings?leagueId=103"

FANGRAPHS_PLAYOFF_ODDS = "https://www.fangraphs.com/api/playoff-odds/odds?projectionMode=2&standingsType=div"
#FANGRAPHS_PLAYOFF_ODDS = "https://www.fangraphs.com/api/playoff-odds/odds?dateEnd=2022-04-27&projectionMode=2&standingsType=div"

def main():
    return render.Root(
        delay = 500,
        child = render.Box(
            color = "#003278",
            child = render.Row(
                expanded=True, # Use as much horizontal space as possible
                main_align="start", # controls horizontal alignment
                cross_align="center", # Controls vertical
                children = [
                    render.Padding(
                        child = render.Image(src=RANGERS_ICON_GOLD),
                        pad = 2
                    ),
                    standings_block()
                ],
            )
        )
    )

def standings_block():
    # fetch wins / losses / division rank / wild card rank from MLB.com
    wildCardRank = -1
    res = http.get(url = STANDINGS_API, ttl_seconds = 600)
    if res.status_code != 200:
        fail("Error in fetching mlb.com standings %d - %s" % (res.status_code, res.body()))
    
    divisions = res.json()["records"]
    alWestRecords = getAlWest(divisions)
    rangersRecords = getRangers(alWestRecords)

    wins = int(rangersRecords["wins"])
    losses = int(rangersRecords["losses"])

    divisionRank = int(rangersRecords["divisionRank"])

    # test data for not leading the division
    # alWestRecords = [{"team": {"id":140}, "divisionRank":"2","divisionGamesBack":"2.5"}]    

    # test data for leading the division
    # alWestRecords = [{"team": {"id":140}, "divisionRank":"1","divisionGamesBack":"-"}, {"team": {"id":141}, "divisionRank":"2","divisionGamesBack":"9.5"}]

    # test data for being tied for first in the division
    # alWestRecords = [{"team": {"id":140}, "divisionRank":"2","divisionGamesBack":"-"}]
    gamesDiff = genGamesDiff(alWestRecords)

    if "wildCardRank" in rangersRecords and gamesDiff != 0:
        wildCardRank = int(rangersRecords["wildCardRank"])

    views = [
        record_view(wins, losses),
        al_west_view(divisionRank, gamesDiff)
    ]

    if (wildCardRank != -1):
        views.append(wild_card_view(wildCardRank))

    # fetch playoff odds from fangraphs

    fangraphsRes = http.get(FANGRAPHS_PLAYOFF_ODDS, ttl_seconds = 600)
    if fangraphsRes.status_code != 200:
        fail("Error in fetching Fangraphs playoff odds %d - %s" % (fangraphsRes.status_code, fangraphsRes.body()))

    standingsJson = fangraphsRes.json()
    rangersStandings = fangraphsGetRangers(standingsJson)
    playoffOdds = rangersStandings["endData"]["poffTitle"] * 100
    formattedPlayoffOdds = humanize.float("#.#", playoffOdds)
    divisionOdds = rangersStandings["endData"]["divTitle"] * 100
    formattedDivisionOdds = humanize.float("#.#", divisionOdds)

    if (formattedDivisionOdds == "100.0"):
        views = [
            render.Row(children=[record_view(wins, losses)], main_align="center", expanded=True),
            render.Row(children=[render.Text("AL")], main_align="center", expanded=True),
            render.Row(children=[render.Text("WEST")], main_align="center", expanded=True),
            render.Row(children=[render.Text("CHAMPS")], main_align="center", expanded=True)
        ]
        return render.Column(
            children = views
        )

    if (formattedPlayoffOdds == "100.0"):
        views.append(
            render.Animation(
                children = [
                    render.Text("P: 100% !"),
                    render.Text("P: 100%")
                ]
            )
        )
    else:
        views.append(render.Text("P: %s%%" % formattedPlayoffOdds))

    if (wildCardRank == -1):
        if (formattedDivisionOdds == "100.0"):
            views.append(
                render.Animation(
                    children = [
                        render.Text("P: 100% !"),
                        render.Text("P: 100%")
                    ]
                )
            )
        else:
            views.append(render.Text("D: %s%%" % formattedDivisionOdds))

    return render.Column(
        children = views
    )

def getAlWest(divisions):
    for division in divisions:
        if division["division"]["id"] == 200:
            return division["teamRecords"]

def getRangers(alWest):
    for team in alWest:
        if team["team"]["id"] == 140:
            return team

def genGamesDiff(alWest):
    rangers = getRangers(alWest)
    if rangers["divisionRank"] != "1":
        if rangers["divisionGamesBack"] == "-":
            return 0
        return float(rangers["divisionGamesBack"]) * -1
    smallestGamesBack = 162.0
    for rival in alWest:
        if rival["team"]["id"] != 140 and float(rival["divisionGamesBack"]) < smallestGamesBack:
            smallestGamesBack = float(rival["divisionGamesBack"])
    return float(smallestGamesBack)

def record_view(wins, losses):
    return render.Text(content = "{}-{}".format(wins, losses), color = "#FF0")

def al_west_view(rank, gamesDiff):
    if gamesDiff == 0:
        return render.Text("{} (-)".format(humanize.ordinal(1)))
    formatString = "{} (+{})" if (gamesDiff > 0) else "{} ({})"
    return render.Text(formatString.format(humanize.ordinal(rank), gamesDiff))

def wild_card_view(rank):
    return render.Text("WC: %s" % humanize.ordinal(rank))

def fangraphsGetRangers(standings):
    for team in standings:
        if team["abbName"] == "TEX":
            return team
