require 'thor'
require 'digest'
require 'net/http'
require 'uri'

class Starter < Thor
  include Thor::Actions

  desc 'deploy', 'run deploy to deploy app to VPS Matrix demo server'
  def deploy

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
    end

    @app_name = Dir.pwd.split(File::SEPARATOR).last
    unless Config.new.content['api_key']
      # ask for it to server
      api_key = send_get_request "https://api.vpsmatrix.net/uploads/get_api_key", {ssh_key: ssh_key}
      Config.new.write 'api_key', api_key
    end

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

  no_commands do
    def read_files

      # TODO check size of directory
      working_dir = Dir.pwd
      list_of_files = Dir.glob "#{working_dir}/**/*"
      list_of_files.reject! {|path| path =~ /\/log|\/tmp/}
      File.open("files_to_send", 'w') do |temp_file|
        list_of_files.each do |file|
          if File.file? file
            file_content = File.read(file)
            temp_file.write "#{file}\n"
            temp_file.write "#{file_content}\n"
            temp_file.write "#{Digest::SHA256.hexdigest(file_content)}\n"
          end
        end
      end
    end

    def stream_file
      uri = URI.parse("https://api.vpsmatrix.net/uploads/send_new_files")

      # stream version
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Put.new(uri)
        req.add_field('Transfer-Encoding', 'chunked')
        request.basic_auth("test_app", "test_app")
        req.body_stream = File.open("files_to_send")

        http.request request do |response|
          # puts response
          response.read_body do |chunk|
            puts chunk
          end
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
  end
end