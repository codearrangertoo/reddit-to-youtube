#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
gem 'google-api-client', '~> 0.9'
require 'google/apis/youtube_v3'
gem 'googleauth', '~> 0.5'
require 'googleauth'
require 'googleauth/stores/file_token_store'

gem 'rack', '> 1.6'
require 'rack/utils'

require 'json'
require 'open-uri'
require 'pp'


class Youtube

  YOUTUBE_SCOPE = 'https://www.googleapis.com/auth/youtube'
  YOUTUBE_API_SERVICE_NAME = 'youtube'
  YOUTUBE_API_VERSION = 'v3'
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

  def initialize

    @youtube = Google::Apis::YoutubeV3::YouTubeService.new

    client_id = Google::Auth::ClientId.from_file(File.dirname($PROGRAM_NAME) + '/client_secrets.json')
    token_store = Google::Auth::Stores::FileTokenStore.new(
      :file => "#{$PROGRAM_NAME}-oauth2.yaml")
    authorizer = Google::Auth::UserAuthorizer.new(client_id, YOUTUBE_SCOPE, token_store)

    user_id = client_id.id

    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI )
      puts "Open #{url} in your browser and enter the resulting code:"
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end

    @youtube.authorization = credentials

  end

  def get_playlists()

    playlists = []

    begin
        # Retrieve the playlists from the user's channel.
        next_page_token = ''
        until next_page_token.nil?
          playlists_response = @youtube.list_playlists('snippet', :page_token => next_page_token, :mine => true, :max_results => 50)

          ## Read information about each playlist.
          playlists_response.items.each do |playlist|
            data = {}
            data['title'] = playlist.snippet.title
            data['id'] = playlist.id
            playlists.push(data)
          end

          next_page_token = playlists_response.next_page_token

      end
    rescue Google::Apis::ClientError => e
      pp e
    end

    return playlists
  end


  def get_playlist_items(uploads_list_id)

    video_ids = []

    begin
        # Retrieve the playlist items from the playlist_id.
        next_page_token = ''
        until next_page_token.nil?
          playlistitems_response = @youtube.list_playlist_items('snippet', :playlist_id => uploads_list_id, :max_results => 50, :page_token => next_page_token)

          # Read information about each playlist item.
          playlistitems_response.items.each do |playlist_item|
            title = playlist_item.snippet.title
            video_id = playlist_item.snippet.resource_id.video_id
            video_ids.push(video_id)
          end

          next_page_token = playlistitems_response.next_page_token

      end
    rescue Google::Apis::ClientError => e
      pp e
    end

    return video_ids
  end

  def playlist_insert(play_list_id, video_id, note)

      body = {
        :snippet => {
          :playlist_id => play_list_id,
          :resource_id => {
            :kind => 'youtube#video',
            :video_id => video_id
          }
        },
        :content_details => {
          :note => note
        }
      }

      item = Google::Apis::YoutubeV3::PlaylistItem.new(body)
      #pp item

    begin
      playlistitems_response = @youtube.insert_playlist_item('snippet,contentDetails', item)
    rescue Google::Apis::ClientError => e
      pp e
    end

  end

  def new_playlist(title)

      body = {
        :snippet => {
          :title => title,
          :resource_id => {
            :kind => 'youtube#playlist'
          }
        },
        :status => {
          :privacy_status => 'public'
        }
      }

      new_playlist = Google::Apis::YoutubeV3::Playlist.new(body)

    begin
      playlistsinsert_response = @youtube.insert_playlist('snippet,status', new_playlist)
      return playlistsinsert_response.id
    rescue Google::Apis::ClientError => e
      pp e
    end

  end

  def get_current_pl(subreddit='videos')
    date=DateTime.now.strftime('%Y-%m-%d')
    playlist_title="/r/#{subreddit}@#{date}"
    puts "playlist_title=#{playlist_title}"
    if pl=get_playlists.find {|p| p['title'] == playlist_title }
      return pl['id']
    else
      return new_playlist(playlist_title)
    end

  end

end

class Reddit

  def get_feed(sub_reddits)
    url = "https://www.reddit.com/r/#{sub_reddits.join('+')}.json?limit=100"
    json = ""
    begin
      open(url) do |feed|
        json << feed.read
      end
      parsed = JSON.parse(json)
      return parsed
    rescue OpenURI::HTTPError => e
      if e.io.status.first.to_i == 429
        puts "Reddit says \"#{e.io.status.last}\". Sleeping for 5 seconds and trying again."
        sleep 5
        return get_feed(sub_reddits)
      else
        pp e.io
        exit 1
      end
    end
  end

  def get_links(sub_reddits)

    video_ids = []

    reddit_feed = get_feed(sub_reddits)

    reddit_feed['data']['children'].each do |item|
      if item['data']['domain'] =~ /(youtube\.com|youtu\.be)/
        #links.push(item['data']['url'])
        uri = URI.parse(item['data']['url'])
        if uri.host == 'youtu.be'
          vid_id = uri.path[1..-1]
          item['data']['video_id'] = vid_id
          video_ids.push(item['data'])
        else
          if uri.query
            rack_parse = Rack::Utils.parse_query(uri.query)
            if rack_parse.has_key?('v')
              vid_id = rack_parse['v']
            else
              if uri.path =~ /attribution_link/ && rack_parse.has_key?('u')
                new_uri = URI.parse(uri.scheme + '//' + uri.host + rack_parse['u'])
                sub_rack_parse = Rack::Utils.parse_query(new_uri.query)
                vid_id = sub_rack_parse['v'] if sub_rack_parse.has_key?('v')
              end
            end
            item['data']['video_id'] = vid_id
            video_ids.push(item['data'])
          end
        end
      end
    end
    return video_ids
  end
    
end

youtube=Youtube.new
reddit=Reddit.new

subreddits=['videos', 'funny', 'AnimalsBeingBros']

subreddits.each do |subreddit|
  puts "Getting feed from reddit.com/r/#{subreddit}"
  reddit_video_ids = reddit.get_links([subreddit])
  #reddit_video_ids.push(reddit.get_links(['funny']))

  # Remove duplicates
  puts "Removing duplicate videos from list"
  reddit_video_ids.uniq { |v| v['video_id'] }

  puts "Getting current playlist id"
  playlist=youtube.get_current_pl(subreddit)
  puts "Playlist id = #{playlist}"

  playlist_video_ids = youtube.get_playlist_items(playlist)

  reddit_video_ids.each do |item|
    unless playlist_video_ids.include?(item['video_id'])
      puts "Adding: #{item['video_id']}"
      note = "#{item['title']}\nhttps://reddit.com#{item['permalink']}"
      # Make sure the note isn't more than 280 characters
      note = "https://reddit.com#{item['permalink']}" if note.length > 280
      youtube.playlist_insert(playlist, item['video_id'], note)
    end
  end
end
