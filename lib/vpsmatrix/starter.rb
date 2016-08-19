require 'digest'
require 'net/http'
require 'uri'
require 'securerandom'
require_relative 'config'

class Starter


  def self.start args
    @environment = args.shift
    @action = args.shift

    environments = %w{demo prod}
    fail "\nUnknown environment. Available environments: #{environments.join(', ')}" unless environments.include?(@environment)
    actions = %w{deploy}
    fail "\nUknown action. Available actions: #{actions.join(', ')}" unless actions.include?(@action)
    Starter.new.send("#{@environment}_#{@action}")
  end

  #desc 'demo deploy', 'run demo deploy to deploy app to VPS Matrix demo server'
  def prod_deploy
    fail "Not implemented yet."
  end

  def demo_deploy

    ##
    # check SSH key in .vpsmatrix dir, else generate new
      # generate ~/.vpsmatrix/config.yml
      # generate ~/.vpsmatrix/id_rsa.pub

    ## check for .vpsmatrix_config
    ## no?
      # generate .vpsmatrix_config.yml
      # ask for API KEY
      # write it to .vpsmatrix_config.yml
    ## yes?
      # read API KEY


    # there should be only one SSH key for all apps right? So dir in home with general config and SSH key
    # then one config file in app folder?
    unless File.exists? ".vpsmatrix/id_rsa.pub"
      # Generate SSH key
      ssh_key = 'HFKNGEWIUHENINHSLN867G5867BDI7BOQ8YWQF9YFN9QWF'
    end

    @app_name = Dir.pwd.split(File::SEPARATOR).last
    unless Config.new.content['api_key']
      # ask for it to server
      # TODO check if server returns api_key
      api_key = send_get_request "https://api.vpsmatrix.net/uploads/get_api_key", {ssh_key: ssh_key}
      Config.new.write 'api_key', api_key
    end

    #register_email
    read_files
    stream_file

    # https://api.vpsmatrix.net/uploads/get_new_files

    # detect rails? DB in (pg, mysql, sqlite, nodb)?
    # no? - do you wish us to check it?

    # send SSH key and API KEY to API app

    # -> OK
    # upload app to API, use rsync or something easy


    # -> return error message (no account, etc.)

    # run deploy on API app
    # receive DONE deploy -> show URL

  end

    def read_files
      @multipart_boundary = '-'*16 + SecureRandom.hex(32)

      puts 'Writing files to temporary file'
      # TODO check size of directory
      working_dir = Dir.pwd
      list_of_files = Dir.glob "#{working_dir}/**/*"
      list_of_files.reject! {|path| path =~ /#{working_dir}\/log|#{working_dir}\/tmp/}
      File.open("tmp/files_to_send", 'w') do |temp_file|
        temp_file.write "#{@multipart_boundary}\n"
        list_of_files.each do |file|
          if File.file? file
            file_content = File.read(file)
            temp_file.write "#{working_dir.split('/').last + file.split(working_dir).last}\n"
            temp_file.write "#{file_content.size}\n"
            temp_file.write "#{file_content}\n"
            temp_file.write "#{Digest::SHA256.hexdigest(file_content)}\n"
          end
        end
        temp_file.write "#{@multipart_boundary}\n"
      end
    end

    def stream_file
      puts 'Stream file to server'
      uri = URI.parse("https://api.vpsmatrix.net/uploads/send_new_files")

      # stream version
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Put.new(uri)
        req.add_field("Content-Type","multipart/form-data; boundary=#{@multipart_boundary}")
        req.add_field('Transfer-Encoding', 'chunked')
        req.basic_auth("test_app", "test_app")
        req.body_stream = File.open("files_to_send")

        http.request req do |response|
          # puts response
          response.read_body do |chunk|
            puts chunk
          end
          puts response.code
        end
      end
    end

    def send_put_request
      uri = URI.parse("https://api.vpsmatrix.net/uploads/send_new_files")

      # no stream version
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Put.new(uri.request_uri)
        request.basic_auth("test_app", "test_app")
        request.set_form_data({"file" => File.read("files_to_send")})
        http.request request
      end
    end

    def send_get_request endpoint, params={} #https://api.vpsmatrix.net/uploads/get_file_list
      uri = URI.parse(endpoint)
      uri.query = URI.encode_www_form(params)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.path)
      req.basic_auth("test_app", "test_app")
      http.request(req)
      #res = Net::HTTP.get_response(uri)
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


def register_email
  puts 'Thank you very much for using vpsmatrix. You are awesome!

We are just a month in this world and still working on
full implementation of CLI functionality. We wish deployment to be the
easiest step in development for everybody.
'
  puts
  print 'Do you want to help us improve our solution [y/n] '

  reply=$stdin.gets.chop

  if reply.downcase == 'y'

    puts 'At this point we would love to get your email address so we can kindly
inform you when we are ready to present working functionality. And we are
eager to hear how you feel ideal deployment should look like
at ideas@vpsmatrix.com !'

    puts
    print 'Your email: '

    email = $stdin.gets.chop

    uri = URI.parse("https://api.vpsmatrix.net/registration/gem")
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri)
      request.set_form_data({"email" => email})
      response = http.request(request)
      puts response.body
   end
 

      puts 'Thank you very much. Speak to you soon!'

  else
    puts
    puts 'Thank you very much. We hope we meet in future where we will be more ready to help you ;)'
  end
  puts


  end
end