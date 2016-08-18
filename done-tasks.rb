require 'sinatra'
require 'json'
require 'rest-client'
require 'wunderlist'
require './done-tasks-credentials'

OAUTH_URL =
"https://www.wunderlist.com/oauth/authorize?client_id=%{client_id}&redirect_uri=%{redirect_url}&state=%{state}"

ACCESS_CODE_URL = "https://www.wunderlist.com/oauth/access_token"

VALID_STATES = []

enable :sessions

get '/' do
  if not session['access_code']
    state = (0...20).map { ('a'..'z').to_a[rand(26)] }.join
    VALID_STATES << state
    redirect to(OAUTH_URL % {:client_id => Credentials::CLIENT_ID, :redirect_url => Credentials::REDIRECT_URL, :state => state})
  else 
    wl = Wunderlist::API.new({
      :access_token => session[:access_code],
      :client_id => Credentials::CLIENT_ID
    }) 

    user = wl.user
    lists = wl.lists
    tasks = lists.flat_map { |l| l.tasks(:completed => true) }
    tasks = tasks.select { |t| t.completed_by_id == user.id }
    tasks_per_week = tasks.group_by do |t|
      DateTime.iso8601(t.completed_at).to_date
    end
    tasks_per_week = tasks_per_week.select do |day, t|
      Date.today - day < 7
    end
    tasks_per_week = tasks_per_week.sort.reverse

    erb :index, :locals => { :tasks_per_week => tasks_per_week, :user_name => user.name }
  end
end

get '/authorize' do
  if VALID_STATES.include? params['state'] then
    VALID_STATES.delete(params['state'])

    access_code_request_data = {
      "client_id" => Credentials::CLIENT_ID,
      "client_secret" => Credentials::CLIENT_SECRET,
      "code" => params['code']
    }
    response = RestClient.post ACCESS_CODE_URL, access_code_request_data.to_json, :content_type => :json, :accept => :json

    case response.code
    when 200
      access_code = JSON.parse(response.body)['access_token']

      session[:access_code] = access_code
      redirect to('/')
    else
      return 502
    end
  else 
    return 502
  end
end

get '/favicon.ico' do
  [200, {"Content-Type" => "image/png"}, File.read('favicon.png')]
end
