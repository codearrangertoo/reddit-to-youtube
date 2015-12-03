#!/usr/bin/env ruby

require 'rubygems'
gem 'google-api-client', '>0.7'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'

require 'rss'
require 'open-uri'
require 'mechanize'

# This OAuth 2.0 access scope allows for read-only access to the authenticated
# user's account, but not other types of account access.
YOUTUBE_READONLY_SCOPE = 'https://www.googleapis.com/auth/youtube'
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'

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
      :scope => [YOUTUBE_READONLY_SCOPE]
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
      # Retrieve the list of videos uploaded to the authenticated user's channel.
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
        
        # Print information about each video.
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
  agent = Mechanize.new
  url = "https://www.reddit.com/r/#{sub_reddits.join('+')}.rss?limit=100"
  links = []
  video_ids = []
  begin
    open(url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        page = Mechanize::Page.new nil, nil, item.description, 200, agent
        page.links_with(:href => /^https?:\/\/(youtu\.be|(www\.)?youtube\.com)/).each do |link|
        	links.push(link.href)
        end
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

puts get_reddit_links(['funny'])
exit

reddit_video_ids = get_reddit_links(['videos'])
#reddit_video_ids.push(get_reddit_links(['funny']))
reddit_video_ids = reddit_video_ids.uniq

playlist_video_ids = get_playlist_items('PLWpGgXK-klw8l3UUiKNE-fWzVmy-LEnbb')

reddit_video_ids.each do |video_id|
	unless playlist_video_ids.include?(video_id)
	  puts "Adding: #{video_id}"
    playlist_insert('PLWpGgXK-klw8l3UUiKNE-fWzVmy-LEnbb', video_id)
	end
end

#reddit_video_data = get_video_data(reddit_video_ids)
