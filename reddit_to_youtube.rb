#!/usr/bin/env ruby

require 'rubygems'
gem 'google-api-client', '>0.7'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'

require 'json'
require 'open-uri'

YOUTUBE_SCOPE = 'https://www.googleapis.com/auth/youtube'
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'

playlist = 'PL65vUm4YoczPlyA7Q5O-5D77t5iLRLQXQ'

def get_authenticated_service
  client = Google::APIClient.new(
    :application_name => $PROGRAM_NAME,
    :application_version => '1.0.0'
  )
  youtube = client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)

  file_storage = Google::APIClient::FileStorage.new("#{$PROGRAM_NAME}-oauth2.json")
  if file_storage.authorization.nil?
    client_secrets = Google::APIClient::ClientSecrets.load
    flow = Google::APIClient::InstalledAppFlow.new(
      :client_id => client_secrets.client_id,
      :client_secret => client_secrets.client_secret,
      :scope => [YOUTUBE_SCOPE]
    )
    client.authorization = flow.authorize(file_storage)
  else
    client.authorization = file_storage.authorization
  end

  return client, youtube
end

def get_video_data(video_ids)
  client, youtube = get_authenticated_service

  begin
      next_page_token = ''
      until next_page_token.nil?
        videos_list_response = client.execute!(
          :api_method => youtube.videos.list,
          :parameters => {
            :part => 'snippet',
            :id => video_ids.join(","),
            :pageToken => next_page_token
          }
        )

        return videos_list_response.data.items

        videos_list_response.data.items.each do |video_item|
          puts video_item.inspect
          #title = playlist_item['snippet']['title']
          #video_id = playlist_item['snippet']['resourceId']['videoId']
        end

        next_page_token = videos_list_response.next_page_token

    end
  rescue Google::APIClient::TransmissionError => e
    puts e.result.body
  end

end


def get_playlist_items(uploads_list_id)
  client, youtube = get_authenticated_service

  video_ids = []

  begin
      # Retrieve the list of videos uploaded to the authenticated user's channel.
      next_page_token = ''
      until next_page_token.nil?
        playlistitems_response = client.execute!(
          :api_method => youtube.playlist_items.list,
          :parameters => {
            :playlistId => uploads_list_id,
            :part => 'snippet',
            :maxResults => 50,
            :pageToken => next_page_token
          }
        )

        # Print information about each video.
        playlistitems_response.data.items.each do |playlist_item|
          title = playlist_item['snippet']['title']
          video_id = playlist_item['snippet']['resourceId']['videoId']
          video_ids.push(video_id)
        end

        next_page_token = playlistitems_response.next_page_token

    end
  rescue Google::APIClient::TransmissionError => e
    puts e.result.body
  end

  return video_ids
end

def playlist_insert(play_list_id, video_id)
  client, youtube = get_authenticated_service

    body = {
      :snippet => {
        :playlistId => play_list_id,
        :resourceId => {
          :kind => 'youtube#video',
          :videoId => video_id
        }
      }
    }

  begin
        playlistitems_response = client.execute!(
          :api_method => youtube.playlist_items.insert,
          :body_object => body,
          :parameters => {
            :part => 'snippet'
          }
        )
  rescue Google::APIClient::TransmissionError => e
    puts e.result.body
  end

end

def get_reddit_links(sub_reddits)
  url = "https://www.reddit.com/r/#{sub_reddits.join('+')}.json?limit=100"
  links = []
  video_ids = []
  json = ""
  begin
    open(url) do |feed|
    	json << feed.read
    end
    parsed = JSON.parse(json)
    parsed['data']['children'].each do |item|
    	if item['data']['domain'] =~ /(youtube\.com|youtu\.be)/
    		links.push(item['data']['url'])
    	end
    end
  rescue OpenURI::HTTPError => e
    puts e.inspect
  end

  links.each do |link|
    uri = URI.parse(link)
    if uri.host == "youtu.be"
      video_ids.push(uri.path[1..-1])
    else
      vid_id = uri.query.sub(/.*v=([a-zA-Z0-9\-\_]+).*/, '\1')
      video_ids.push(vid_id)
    end
  end
  return video_ids
end

reddit_video_ids = get_reddit_links(['videos'])
#reddit_video_ids.push(get_reddit_links(['funny']))
reddit_video_ids = reddit_video_ids.uniq

playlist_video_ids = get_playlist_items(playlist)

reddit_video_ids.each do |video_id|
  unless playlist_video_ids.include?(video_id)
    puts "Adding: #{video_id}"
    playlist_insert(playlist, video_id)
  end
end

#reddit_video_data = get_video_data(reddit_video_ids)
