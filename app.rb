require 'rubygems'
require 'sinatra'
require 'tweetstream'
require 'redis'
require 'json'
require 'stopwords'

set :server, 'webrick'

post '/tweets' do
  redis = Redis.new
  TweetStream.configure do |config|
    config.consumer_key = ENV['CONSUMER_KEY']
    config.consumer_secret    = ENV['CONSUMER_SECRET']
    config.oauth_token        = ENV['ACCESS_TOKEN']
    config.oauth_token_secret = ENV['ACCESS_TOKEN_SECRET']
    config.auth_method        = :oauth
  end
  # This will pull a sample of all tweets based on
  # your Twitter account's Streaming API role.
  beginning_time = Time.now
  puts 'before the tweetstream'
  # This will pull a sample of all tweets based on
  # your Twitter account's Streaming API role.
  filter = Stopwords::Snowball::Filter.new 'en'

  TweetStream::Client.new.sample(language: 'en') do |status|
    # The status object is a special Hash with
    # method access to its keys.
    # puts status.text.to_s
    text = status.text.to_s.split
    filtered_words = filter.filter(text)
    filtered_words.each do |word|
      word_exist = redis.exists(word)
      if word_exist
        redis.zincrby('zset', 1, word)
        puts ">>>>>>>>>> WORD #{word} ALREADY IN REDIS, VALUE #{redis.get(word)} <<<<<<<<<<<<<<"
      else
        puts ">>>>>>>>>> WORD #{word} NOT IN REDIS, INSERTING FOR THE FIRST TIME  <<<<<<<<<<<<<<"
        redis.zadd('zset', 1, word)
     end
      # word_exist ? redis.set(word, redis.get(word) + 1) : redis.set(word, 1)
    end
    end_time = Time.now
    miliseconds = (end_time - beginning_time) * 1000
    client.stop if miliseconds >= 300_000
    # 5 minutes = 300000 ms
    # 30 secs = 30000 ms
  end
  # We save the number of stopwords
end

get '/words' do
  redis = Redis.new
  return redis.zrevrangebyscore('zset',
                                '+inf',
                                '-inf',
                                with_scores: true,
                                limit: [0, 10])
              .to_json
end

get '/' do
end
