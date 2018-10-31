# Description
This tool will create a daily youtube playlists with videos from a handful of subreddits
https://www.youtube.com/channel/UCtiHeacPZOkhZzOu1MC2EmQ/playlists

# Getting started
Create a client_secrets.json file from https://console.developers.google.com/apis/credentials

## Docker
```
docker build ./
docker run -i (new image id)
docker ps -a
```

Find the docker container name. In my case it was blissful_hoover

Add this to your crontab:

```
crontab -e
```

```
*/30 * * * * /usr/bin/docker start blissful_hoover -a
```
