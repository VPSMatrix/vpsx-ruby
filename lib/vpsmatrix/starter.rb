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



  def self.start args
    @action = args.shift
    @environment = args.shift

    #environments = %w{demo prod}
    #fail "\nUnknown environment. Available environments: #{environments.join(', ')}" unless environments.include?(@environment)
    #actions = %w{deploy init}
    #fail "\nUknown action. Available actions: #{actions.join(', ')}" unless actions.include?(@action)
    case @action
      when "deploy"
        Starter.new.send("#{@environment}_#{@action}")
      when "config"
        Starter.new.send(@action)
      else
        fail "No action like this."
    end
  end


  # Login user; create if not existing; add api_key to ~/.vpsx.yml for future use
  def login
    # check ~/.vpsx.yml for api key
    @config = Config.new("home")
    return @config.content['api_key'] if Config.new("home").content['api_key']

    puts "Getting api key"
    email = prompt(nil, "Insert email: ")
    p email
    password = prompt(nil, "Insert password (provide new if new user): ")
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

  # Configure how app is
  def config
    @app_config = Config.new
    api_key = login

    resolve_vps(api_key)
    resolve_upload_strategy

    app_name = `pwd`.split("/").last.gsub("\n", "")
    @app_config.write("app_name", app_name)
    ## create service user
    # API will check existing "service" user in VPS -> for communication between user's VPSs
    # if not it will be created with ssh keys -> these keys will be saved to ~/.vpsx.yml (used for all other VPS)
    # take private ssh key from existing server

    # TODO check if user exists
    ssh_key_for_git = create_app_user(api_key)
    puts ssh_key_for_git

    resolve_database
    resolve_domain

    ## TODO solve this
    ## ask user for any ENV variables he may need? Like mailgun? mail server? redis? anything else?
    # pass ENV variables to set settings of projects
  end

  def prod_deploy
    # TODO should be more sofisticated -> now in case of problems during .vpsx.yml creation there is no possibility to go back to questionnaire
    # TODO do some checks of validity of .vpsx.yml !!!
    return puts("There is no config file. Run vpsx config first.") && abort unless File.exist?(".vpsx.yml") # && is_valid?

    @app_config = Config.new
    api_key = login # use api for all the rest of communication

    # send to API and install on chosen VPS
    puts 'Deploying app'
    uri = URI.parse("#{Vpsmatrix::API_TEST_SERVER}/uploads/deploy_to_production")

    Net::HTTP.start(uri.host, 3000, :read_timeout => 500) do |http|
      req = Net::HTTP::Put.new(uri)
      req.add_field("Content-Type","multipart/form-data;")
      req.add_field('Transfer-Encoding', 'chunked')
      req['authorization'] = "Token token=#{api_key}"
      req.set_form_data(@app_config.content)

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

  #desc 'demo deploy', 'run demo deploy to deploy app to VPS Matrix demo server'
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