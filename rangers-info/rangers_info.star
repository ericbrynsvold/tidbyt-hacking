load("render.star", "render")
load("encoding/base64.star", "base64")
load("humanize.star", "humanize")
load("http.star", "http")
load("cache.star", "cache")
load("encoding/json.star", "json")

RANGERS_ICON = base64.decode("iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAfklEQVQ4T2NUMEn6z0ABYIQZcP/0XJKMUTRNBqsn24B3sqoMxhJ2qAbABGFOgbkKmzj1DQDZevbFIbCzCLkAWS08DLCFIC4vIKvFaQB6rMBCHd0iol0A0ojsPZhBRBuATTNKOqB6GIAMHNhARI8F9NRIVCCCEhYyIDkWiMmeAAbGZWGVxIGMAAAAAElFTkSuQmCC")

BASE_URL = "https://statsapi.mlb.com/api/"
STANDINGS_API = BASE_URL + "v1/standings?leagueId=103"

FANGRAPHS_PLAYOFF_ODDS = "https://www.fangraphs.com/api/playoff-odds/odds?projectionMode=2&standingsType=div"
#FANGRAPHS_PLAYOFF_ODDS = "https://www.fangraphs.com/api/playoff-odds/odds?dateEnd=2022-04-27&projectionMode=2&standingsType=div"

def main():
    return render.Root(
        child = render.Box(
            render.Row(
                expanded=True, # Use as much horizontal space as possible
                main_align="space_evenly", # controls horizontal alignment
                cross_align="center", # Controls vertical
                children = [
                    render.Image(src=RANGERS_ICON),
                    standings_block()
                ],
            )
        )
    )

def standings_block():
    standings_cached_json = cache.get("rangers_standings")
    wildCardRank = -1

    if standings_cached_json == None:
        print("no cached MLB data, fetching")
        rep = http.get(STANDINGS_API)
        if rep.status_code != 200:
            fail("there was an error", rep.status_code)

        divisions = rep.json()["records"]
        alWestRecords = getAlWest(divisions)
        rangersRecords = getRangers(alWestRecords)

        wins = int(rangersRecords["wins"])
        losses = int(rangersRecords["losses"])

        divisionRank = int(rangersRecords["divisionRank"])

        if "wildCardRank" in rangersRecords:
            wildCardRank = int(rangersRecords["wildCardRank"])

        cacheDict = {
            "wins": wins,
            "losses": losses,
            "divisionRank": divisionRank,
            "wildCardRank": wildCardRank
        }
        cacheDictJson = json.encode(cacheDict)
        cache.set("rangers_standings", cacheDictJson, ttl_seconds=600)

    else:
        print("MLB cache hit")
        standings_cached = json.decode(standings_cached_json)
        wins = standings_cached["wins"]
        losses = standings_cached["losses"]
        divisionRank = standings_cached["divisionRank"]
        wildCardRank = standings_cached["wildCardRank"]

    views = [
        record_view(wins, losses),
        al_west_view(divisionRank)
    ]

    if (wildCardRank != -1):
        views.append(wild_card_view(wildCardRank))

    formattedPlayoffOdds = cache.get("rangers_playoff_odds")

    if formattedPlayoffOdds == None:
        print("no cached Fangraphs data, fetching")
        rep = http.get(FANGRAPHS_PLAYOFF_ODDS)
        if rep.status_code != 200:
            fail("there was an error", rep.status_code)

        standingsJson = rep.json()
        rangersStandings = fangraphsGetRangers(standingsJson)
        playoffOdds = rangersStandings["endData"]["poffTitle"] * 100
        
        formattedPlayoffOdds = humanize.float("#.##", playoffOdds)
        cache.set("rangers_playoff_odds", formattedPlayoffOdds, ttl_seconds=600)
    else:
        print("Fangraphs cache hit")
    
    views.append(render.Text("P: %s%%" % formattedPlayoffOdds))

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

def record_view(wins, losses):
    return render.Text("{}-{}".format(wins, losses))

def al_west_view(rank):
    return render.Text("ALW: %s" % humanize.ordinal(rank))

def wild_card_view(rank):
    return render.Text("WC: %s" % humanize.ordinal(rank))

def fangraphsGetRangers(standings):
    for team in standings:
        if team["abbName"] == "TEX":
            return team