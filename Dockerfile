FROM debian:stretch
LABEL version="1.0" maintainer="Jason Garland <jason@jasongarland.com>"

#Install dependencies
RUN apt-get update
RUN apt-get install -y gem bundler watch

RUN mkdir -p /opt/reddit-to-youtube

COPY reddit_to_youtube.rb Gemfile /opt/reddit-to-youtube/
COPY client_secrets.json reddit_to_youtube.rb-oauth2.yaml /opt/reddit-to-youtube/

WORKDIR /opt/reddit-to-youtube

#Install gems
RUN bundle install --verbose --no-color

#set the timezone
ENV TZ="America/Los_Angeles"

#Start the script
CMD ["/opt/reddit-to-youtube/reddit_to_youtube.rb"]
