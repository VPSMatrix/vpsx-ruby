module Helpers

  # simple prompt with defined text
  # return user's input
  def prompt(*args)
    print(*args)
    gets.gsub("\n", '')
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

end