require 'sinatra'
require 'net/http'
require 'json'

CLIENT_ID = "a9bcc58b3bf5dc9796b2"
CLIENT_SECRET = "7bd2f246e5eb67b9d18653dec325c4b669e28842a5106abf1a87da1bab5e"

OAUTH_URL =
"https://www.wunderlist.com/oauth/authorize?client_id=%{client_id}&redirect_uri=%{redirect_url}&state=%{state}"

REDIRECT_URL = "http://done-tasks.herokuapp.com/authorize"
ACCESS_CODE_URL = "https://www.wunderlist.com/oauth/access_token"

VALID_STATES = []

enable :sessions

get '/' do
  state = (0...20).map { ('a'..'z').to_a[rand(26)] }.join
  VALID_STATES << state
  redirect to(OAUTH_URL % {:client_id => CLIENT_ID, :redirect_url => REDIRECT_URL, :state => state})
end

get '/authorize' do
  if VALID_STATES.include? params['state'] then
    VALID_STATES.delete(params['state'])
    access_code_request_data = {
      "client_id" => CLIENT_ID,
      "client_secret" => CLIENT_SECRET,
      "code" => params['code']
    }
    access_code = JSON.parse(Net::HTTP.post(ACCESS_CODE_URL, access_code_request_data.to_json))['access_token']
    session[:access_code] = access_code
    redirect to('/tasks')
  else 
    return 502
  end
end

get '/tasks' do
  return session[:access_code]
end
