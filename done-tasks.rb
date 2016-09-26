require 'sinatra'
require 'json'
require 'rest-client'
require 'wunderlist'
require 'sqlite3'
require './done-tasks-credentials'
require 'logger'

OAUTH_URL =
"https://www.wunderlist.com/oauth/authorize?client_id=%{client_id}&redirect_uri=%{redirect_url}&state=%{state}"
ACCESS_CODE_URL = "https://www.wunderlist.com/oauth/access_token"

LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::INFO

STATES_DB = SQLite3::Database.new "states.db"

def get_valid_states() 
  return STATES_DB.execute("select value from states").flat_map {|r| r}
end

def add_state(state)
  return STATES_DB.execute("INSERT INTO STATES(value) VALUES(?)", [state])
end

def remove_state(state)
  return STATES_DB.execute("DELETE FROM STATES where value = ?", [state])
end

def get_wunderlist(access_code)
  return Wunderlist::API.new({
    :access_token => access_code,
    :client_id => Credentials::CLIENT_ID
  }) 
end

enable :sessions
set :session_secret, ENV['SESSION_KEY'] || Credentials::SESSION_SECRET

before do
  cache_control :public, :must_revalidate, :max_age => 120
end

get '/' do
  if not session[:access_code]
    LOGGER.info("New access")
    state = (0...40).map { ('a'..'z').to_a[rand(26)] }.join
    add_state(state)
    redirect to(OAUTH_URL % {:client_id => Credentials::CLIENT_ID, :redirect_url => Credentials::REDIRECT_URL, :state => state})
  end

  wl = get_wunderlist(session[:access_code])
  user = wl.user
  erb :index, :locals => { :user_name => user.name }
end

get '/tasks' do
  LOGGER.info("Normal access")
  wl = get_wunderlist(session[:access_code])

  lists = wl.lists
  user = wl.user
  tasks = lists.flat_map { |l| l.tasks(:completed => true) }
  tasks = tasks.select { |t| t.completed_by_id == user.id }
  tasks_per_week = tasks.group_by do |t|
    DateTime.iso8601(t.completed_at).to_date
  end
  tasks_per_week = tasks_per_week.select do |day, t|
    Date.today - day < 7
  end
  tasks_per_week = tasks_per_week.sort.reverse

  erb :tasks, :locals => { :tasks_per_week => tasks_per_week }
end

get '/authorize' do
  if get_valid_states.include? params['state'] then
    remove_state(params['state'])

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
