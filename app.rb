require 'rubygems'
require 'sinatra'
require 'erb'
require 'open-uri'
require 'nokogiri'
require 'digest/md5'
require 'json'

enable :sessions

class Repace < Sinatra::Application
  
  mime_type :gpx, 'text/xml'
  
  # Errors ==================================
  
  errors = {
    "invalid_file"  => "Whoops, looks like that file was invalid. Maybe another?",
    "no_times"      => "That file doesn't have any timing data. Please try another file.",
    "not_gpx"       => "Uh oh, that doesn't look like a .GPX file. Please try again." 
  }
  
  # Helpers ==================================
  
  helpers do
    def route_file(filename)
      File.join(UPLOAD_PATH, filename)
    end
    
    def route_download(filename)
      File.join(UPLOAD_BASE, filename)
    end
    
    def create_filename
      Digest::MD5.hexdigest Time.now.to_s
    end
    
    def parse_xml(filename)
      f = File.open(route_file(filename))
      @doc = Nokogiri::XML(f)
      f.close
    end
    
    def parse_remote_xml(uri)
      f = open(uri).read
      @doc = Nokogiri::XML(f)
    end
    
    def valid_xml
      Nokogiri::XML::Schema(File.read("gpx.xsd")).validate(@doc)
    end
    
    def is_file
      params[:file]
    end
    
    def valid_extension
      params[:file][:filename].split(".")[1] == "gpx"
    end
    
    def has_times
      @doc.xpath("//xmlns:trkpt[1]/xmlns:time")
    end
    
    def list_times
      @times = @doc.xpath("//xmlns:trkpt/xmlns:time")
    end
    
    def track_count
      @times.length
    end
    
    def original_name
      @doc.xpath("//xmlns:trk/xmlns:name").text
    end
    
    def original_start
      Time.parse(@doc.xpath("//xmlns:trkpt[1]/xmlns:time").text)
    end
    
    def original_end
      Time.parse(@doc.xpath("//xmlns:trkpt[last()]/xmlns:time").text)
    end
    
    def update_metadata 
      # creator
      @doc.xpath("/xmlns:gpx").each do |node|
        node['creator'] = "Repace.me"
      end
      
      # link to the site   
      @doc.xpath("//xmlns:metadata/xmlns:link").each do |node|
        node['href'] = "http://repace.me"
      end
      
      # metadata tag content
      @doc.xpath("//xmlns:metadata/xmlns:link/xmlns:text").each do |node|
        node.content = "Repace.me"
      end
    end
    
    def original_duration
      original_end.to_f - original_start.to_f
    end
    
    def valid_duration
      params[:hours] = 0..48
      params[:minutes] = 0..60
      params[:seconds] = 0..60
    end
    
    def new_goal
      ((params[:hours].to_i * 3600) + (params[:minutes].to_i * 60) + (params[:seconds].to_i))
    end
    
    def show_offset
      (new_goal - original_duration) / track_count
    end
    
    def write_file(filename, contents)
      f = File.open(filename, 'w')
      f.write contents
      f.close
    end
  end
  
  # Allow alternative ERB layouts ===========
  
  def alt_layout(template, layout, options={})
    erb template, options.merge(:layout => layout)
  end
  
  # Routes ==================================
  
  get '/' do
    alt_layout :blank, :layout_simple
  end
  
  get '/beta/?' do
    # clear the filename from the session
    session[:filename] = ''
    erb :index
  end
  
  get '/strava' do
    @strava_id = "#{('http://app.strava.com/rides/2984423').split('/')[4]}"
    puts "http://app.strava.com/activities/#{@strava_id}/export_gpx"
  end
  
  post '/upload' do
    if is_file.nil?
      # send response as text/plain
      content_type :text
      { :valid => 'false', :message => 'Please select a file to upload!' }.to_json
    else
      if valid_extension
    
        # create a unique filename and upload it
        session[:filename] = "#{create_filename}.xml"
    
        # write the original file with its new name
        write_file(route_file(session[:filename]), params[:file][:tempfile].read)
    
        # start XML parser
        parse_xml(session[:filename])
    
        # only continue if the XML is valid
        if valid_xml.empty?
          # fail if the file lacks timing data
          if has_times.empty?
            # send error
            halt 401, {'Content-Type' => 'text/plain'}, errors["no_times"]
          else
            # pass the event name and original duration to the UI
            @name = original_name
            @duration = Time.at(original_duration).gmtime.strftime('%R:%S')

            # send response as text/plain
            content_type :text
            { :message => 'Upload successful!', :name => @name, :duration => @duration }.to_json
          end
        else
          # clean up upload since it was invalid
          File.delete(route_file(session[:filename]))
      
          # send error
          halt 401, {'Content-Type' => 'text/plain'}, errors["invalid_file"]
        end
      else
        # send error
        halt 401, {'Content-Type' => 'text/plain'}, errors["not_gpx"]
      end
    end
  end
  
  post '/convert' do
    # start XML parser
    parse_xml(session[:filename])
    
    # find all the time nodes
    list_times
          
    # how much should we increment each track?
    @offset = show_offset
        
    # convert old times to new times, in UTC format -- needs to be faster!
    @times.each_with_index do |time, index|
      time.content = Time.at(Time.parse(time.text).to_f + (@offset * index).ceil).gmtime.strftime("%Y-%m-%d\T%H:%M:%S\.000\Z")
    end
    
    # change basic metadata
    update_metadata
  
    # same filename as original, different extension
    convertedfile = "#{session[:filename].split('.')[0]}.gpx"
  
    # save the converted file
    write_file(route_file(convertedfile), @doc)
  
    # display the URL path
    @filepath = route_download(convertedfile)

    # send response as text/plain
    content_type :text
    { :valid => 'true', :download => @filepath }.to_json
  end
end