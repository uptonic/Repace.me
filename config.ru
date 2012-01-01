# =========================
# FOR DREAMHOST
#
#ENV['GEM_HOME'] = '/home/uptonic/.gems'
#ENV['GEM_PATH'] = '$GEM_HOME:/usr/lib/ruby/gems/1.8'
#require 'rubygems'
#Gem.clear_paths

#require 'sinatra'
#require 'erb'
#require 'nokogiri'
#require 'open-uri'
#require 'digest/md5'
#require 'json'
 
#set :run, false
#set :environment, :production

#require 'app'

#run Sinatra::Application


# =========================
# FOR LOCAL DEVELOPMENT

require 'app'

use Rack::ShowExceptions

# set upload location
UPLOAD_BASE = "uploads"
UPLOAD_PATH = "#{File.dirname(__FILE__)}/public/#{UPLOAD_BASE}"

# start the app
run Repace.new