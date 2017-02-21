require 'digest'
require 'net/http'
require 'uri'
require 'json'
require 'securerandom'
require_relative 'config'
require_relative 'upload_progress'

require_relative 'helpers'
include Helpers

class Starter

  API_SERVER = "https://api.vpsmatrix.net"
  API_TEST_SERVER = "http://localhost:3000"

  def self.start args
    @environment = args.shift
    @action = args.shift

    environments = %w{demo prod}
    fail "\nUnknown environment. Available environments: #{environments.join(', ')}" unless environments.include?(@environment)
    actions = %w{deploy}
    fail "\nUknown action. Available actions: #{actions.join(', ')}" unless actions.include?(@action)
    Starter.new.send("#{@environment}_#{@action}")
  end


  def login
    # check ~/.vpsx.yml for api key
    @config = Config.new("home")
    return @config.content['api_key'] if Config.new("home").content['api_key']

    puts "Getting api key"
    email = prompt("Insert email: ")
    p email
    password = prompt("Insert password (provide new if new user): ")
    res = send_put_request "#{API_TEST_SERVER}/login", {email: email, password: password}
    json = JSON.parse(res.body)
    case
      when json["result"] == "ok"
        # save api_key to ~/.vpsx.yml
        puts json["api_key"]
        @config.write 'api_key', json["api_key"]
        @config.content['api_key']
      when json["result"] == "new_account"
        puts "Confirm your e-mail and run this script again"
        # TODO find way how to get back after user confirmed mail (run login again?)
        abort
      else
        puts "There is something very bad, call help."
        abort
    end
  end

  #desc 'demo deploy', 'run demo deploy to deploy app to VPS Matrix demo server'
  def prod_deploy
    @user_config = Config.new("home")
    @app_config = Config.new

    # FIRST RUN in project
    # login to VPSmatrix account - use token or username/password -> save to ~/.vpsx.yml
    # receive API key and use it next time
    ## VPS matrix config for user identification in home dir
    ## register if not existing user
    ## create account with inserted e-mail
    ## confirm email and return (nice text)

    api_key = login # use api for all the rest of communication

    res = send_get_request "#{API_TEST_SERVER}/vps/list_available", {}, api_key

    if res.code == "200"
      vps_list = JSON.parse res.body
      vps_string = vps_list.map {|vps| "#{vps["id"]}: #{vps["hostname"]} at #{vps["ip"]}"}
      vps_id = prompt vps_string.join("\n") + "\n"
      chosen_vps = vps_list.select {|vps| vps["id"].to_s == vps_id}.first
      if chosen_vps.empty?
        puts "No such vps exists. Use existing id please." # TODO let's user continue somehow (run prompt again?)
        abort
      else
        # TODO is there more efficient way how to write to YML file? This just opens and closes file again and again. Maybe open it at beginning?
        @app_config = Config.new.write("host", chosen_vps["ip"])
        @app_config = Config.new.write("host_id", chosen_vps["id"])
      end
      puts chosen_vps["hostname"]
    else
      puts "Check your api_key in ~/.vpsx.yml; call support"
    end








    ## CREATE OR CHOOSE VPS
    # if none create VPS in background (take from pool of created)
    ## ask if to deploy to existing VPS or create new

    # GET request get_list_of_vps(account)
    # POST request create_vps(account, user_ssh_key_pub, service_ssh_key_pub, service_ssh_key_priv)

    # API will check existing "service" user in VPS -> for communication between user's VPSs
    # if not it will be created with ssh keys -> these keys will be saved to ~/.vpsx.yml (used for all other VPS)
    # take private ssh key from existing server

    # user for every app

    # create user for app -> will have different deploy key for each app/user
    # add current_user ssh pub key to deploy app user

    # let user to choose upload strategy
    ## stream all files
    ## git pull from existing repository, then we need url, access (user/pass, insert service ssh key to your git)
    ## ask user to add pub key to git provider -> next step open windows with github/gitlab/bitbucket


    # let user choose where database is
    ## mysql is installed with root user without pass

    # ask for domain to put in nginx.conf
    # pass ENV variables to set settings of projects
    
    # write all to config
    # read all needed config options

=begin
    config = Config.new.content

    # do some checks
    host = config["host"] # VPS used
    user_name = config["user_name"]
    pass = config["pass"]
    git_url = config["git_url"]
    git_user = config["git_user"]
    git_pass = config["git_pass"]
    sql_user = config["sql_user"]
    sql_pass = config["sql_pass"]
    server_name = config["server_name"]
    app_name = `pwd`.split("/").last.gsub("\n", "")

    unless host || user_name || pass || git_user || git_url || git_pass || sql_user || sql_pass || server_name
      fail "Some configuration options are missing, check vpsx.yml"
    end

    # send to API and install on chosen VPS
    puts 'Deploying app'
    uri = URI.parse("#{API_TEST_SERVER}/uploads/deploy_to_own")
    # stream version

    Net::HTTP.start(uri.host, 3000, :read_timeout => 500) do |http|
      req = Net::HTTP::Put.new(uri)
      req.add_field("Content-Type","multipart/form-data;")
      req.add_field('Transfer-Encoding', 'chunked')
      # add some proper authentication
      req.basic_auth("test_app", "test_app")
      req.set_form_data({host: host,
                         user_name: user_name,
                         pass: pass,
                         git_url: git_url,
                         git_user: git_user,
                         git_pass: git_pass,
                         sql_user: sql_user,
                         sql_pass: sql_pass,
                         server_name: server_name,
                         app_name: app_name})

      http.request req do |response|
        puts ""
        response.read_body do |chunk|
          print chunk
        end
        if response.code != '200'
          puts response.code
        end
      end
    end
=end
  end

  def demo_deploy

    unless Config.new.content['ssh_key']
      Config.new.write 'ssh_key', SecureRandom.hex
    end

    @app_name = Dir.pwd.split(File::SEPARATOR).last
    unless Config.new.content['api_key'] && Config.new.content['api_key'].length == 32
      # ask for it to server
      # TODO check if server returns api_key
      api_key = send_get_request "https://api.vpsmatrix.net/uploads/get_api_key"
      if api_key.response.code == '200'
        Config.new.write 'api_key', api_key.response.body
      end
    end

    #register_email
    read_files
    stream_file
  end

    def read_files
      @multipart_boundary = '-'*16 + SecureRandom.hex(32)

      puts 'Writing files to temporary file'
      # TODO check size of directory
      working_dir = Dir.pwd
      list_of_files = Dir.glob "#{working_dir}/**/*"
      list_of_files.reject! {|path| path =~ /#{working_dir}\/log|#{working_dir}\/tmp/}
      unless Dir.exists?("tmp")
       Dir.mkdir("tmp")
      end
      File.open("tmp/files_to_send", 'w') do |temp_file|
        temp_file.write "#{@multipart_boundary}\n"
        list_of_files.each do |file|
          if File.file? file
            file_content = File.read(file, mode: 'rb')
            temp_file.write "#{working_dir.split('/').last + file.split(working_dir).last}\n"
            temp_file.write "#{file_content.size}\n"
            temp_file.write "#{file_content}\n"
            temp_file.write "#{Digest::SHA256.hexdigest(file_content)}\n"
          else
            temp_file.write "#{working_dir.split('/').last + file.split(working_dir).last}\n"
            temp_file.write "DIR\n"
          end
        end
        temp_file.write "#{@multipart_boundary}\n"
      end
    end

    def stream_file
      puts 'Stream file to server'
      uri = URI.parse("https://api.vpsmatrix.net/uploads/send_new_files")

      # stream version
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, :read_timeout => 500) do |http|
        req = Net::HTTP::Put.new(uri)
        req.add_field("Content-Type","multipart/form-data; boundary=#{@multipart_boundary}; ssh_key=#{Config.new.content['ssh_key']}; api_key=#{Config.new.content['api_key']}")
        req.add_field('Transfer-Encoding', 'chunked')
        req.basic_auth("test_app", "test_app")
        File.open('tmp/files_to_send', 'rb') do |io|
          req.content_length = io.size
          req.body_stream = io
          UploadProgress.new(req) do |progress|
            print "uploaded so far: #{ progress.upload_size }/#{ io.size }\r"
            $stdout.flush
          end
          http.request req do |response|
            puts ""
            response.read_body do |chunk|
              print chunk
            end
            if response.code != '200'
              puts response.code
            end
          end
        end
      end
    end

    def read_dirs
      working_dir = Dir.pwd
      list_of_files = Dir.glob "#{working_dir}/**/*"
      dirs_string = ""

      list_of_files.map do |file|
        if File.directory file
          dirs_string += "#{file}\n"
        end
      end
      dirs_string
    end
end