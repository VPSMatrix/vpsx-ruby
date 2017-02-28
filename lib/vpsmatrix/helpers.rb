module Helpers
  # simple prompt with defined text
  # return user's input
  def prompt(default, *args)
    print(*args)
    result = gets.strip.gsub("\n", '')
    return result.empty? ? default : result
  end

  # create put request, ssl and api_key optional
  def send_put_request endpoint, params={}, api_key=nil, ssl=false
    uri = URI.parse(endpoint)

    Net::HTTP.start(uri.host, uri.port) do |http|
      http.use_ssl = true if ssl
      request = Net::HTTP::Put.new(uri.request_uri)
      request['authorization'] = "Token token=#{api_key}" if api_key
      request.set_form_data(params)
      http.request request
    end
  end

  # create get request, ssl and api_key optional
  def send_get_request endpoint, params={}, api_key=nil, ssl=false #https://api.vpsmatrix.net/uploads/get_file_list
    uri = URI.parse(endpoint)
    uri.query = URI.encode_www_form(params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if ssl
    req = Net::HTTP::Get.new(uri.path)
    req['authorization'] = "Token token=#{api_key}" if api_key
    http.request(req)
  end

  # user can choose which VPS to use or create new one (get one from pool of prepared VPS)
  def resolve_vps api_key
    res = send_get_request "#{Vpsmatrix::API_TEST_SERVER}/vps/list_available", {}, api_key

    if res.code == "200"
      vps_list = JSON.parse res.body
      vps_string = vps_list.map {|vps| "#{vps["id"]}: #{vps["hostname"]} at #{vps["ip"]}"}
      vps_id = prompt nil, vps_string.join("\n") + "\n"
      chosen_vps = vps_list.select {|vps| vps["id"].to_s == vps_id}.first
      if chosen_vps.empty?
        puts "No such vps exists. Use existing id please." # TODO let's user continue somehow (run prompt again?)
        abort
      else
        # TODO is there more efficient way how to write to YML file? This just opens and closes file again and again. Maybe open it at beginning?
        @app_config.write("host", chosen_vps["ip"])
        @app_config.write("host_id", chosen_vps["id"])
      end
      #puts chosen_vps["hostname"]
    else
      puts "Check your api_key in ~/.vpsx.yml; call support"
    end
  end

  # user may choose how to get files to VPS (git or directory upload)
  def resolve_upload_strategy
    # TODO add possibility to choose which remote to use
    upload_strategy = prompt("1", "How you want to upload files? \n1: Git (origin remote will be used)\n2: Copy all files in folder [NOT IMPLEMENTED]\n")
    if upload_strategy == "1"
      puts "You have no git repository." && abort unless Dir.exist?(".git")
      remote = `git remote get-url origin`.gsub("\n", '')
      @app_config.write("upload_strategy", "git")
      @app_config.write("git_url", remote)
      puts "#{remote} will be used."
    elsif upload_strategy ==  "2"
      @app_config.write("upload_strategy", "stream")
      puts "All files in this directory will be streamed to server."
    else
      puts "You chose invalid option!" && abort
    end
  end

  # choose which database will be used and where (same VPS, remote VPS, remote service)
  def resolve_database
    # let user choose where database is
    ## mysql is installed with root user without pass
    # TODO add more database types as well 'postgres'
    database = prompt("1", "Where database should be stored? \n1: Same VPS\n Other options not available now\n")
    if database == "1"
      @app_config.write("database", "current_vps")
    else
      puts "You chose invalid option!" && abort
    end
  end

  # choose domain which will be added to nginx
  def resolve_domain
    domain = prompt("example.com", "Add domain where app will run (will be used in nginx configuration)\n")
    @app_config.write("domain", domain)
  end

  # will create user with app name on VPS; generate ssh key for him and possibly upload your pub key.
  def create_app_user api_key
    upload_ssh_key = prompt("Y", "Do you want to upload your public ssh key to app user on VPS? (Y/n)\n")
    # TODO consider situation when there is no pub key
    pub_ssh = upload_ssh_key == "Y" ? File.read("#{ENV['HOME']}/.ssh/id_rsa.pub") : ""

    options = @app_config.content.merge({ssh_key: pub_ssh})
    result = send_put_request "#{Vpsmatrix::API_TEST_SERVER}/vps/create_new_user", options, api_key
    if result.code == "200"
      result.body
    else
      puts "Check your api_key in ~/.vpsx.yml; call support" && abort
    end
  end

end