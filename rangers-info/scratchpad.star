load("render.star", "render")
load("http.star", "http")
load("html.star", "html")
load("humanize.star", "humanize")

def main():
    standingsJson = http.get("https://www.fangraphs.com/api/playoff-odds/odds?dateEnd=2022-06-06&dateDelta=&projectionMode=2&standingsType=div&teamId=3").json()
    rangersStandings = getRangers(standingsJson)
    playoffPercentage = rangersStandings["endData"]["poffTitle"] * 100
    print("playoff percentage")
    print(humanize.float("#.##", playoffPercentage)+"%")
    #print(http.get("https://www.fangraphs.com/standings/playoff-odds?date=2022-06-06").body())
    #standingsPage = html(http.get("https://www.fangraphs.com/standings/playoff-odds?date=2022-06-06").body())
    #tables = standingsPage.find(".playoff-odds-app")
    #print("got the HTML")
    #print(standingsPage.text())
    return render.Root(
        child = render.Text("Hello, World!")
    )

def getRangers(standingsJson):
    for team in standingsJson:
        if team["abbName"] == "TEX":
            return team