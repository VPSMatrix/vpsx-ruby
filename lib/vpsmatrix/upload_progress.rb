#the code is used from gem 'net-http-uploadprogress'

class UploadProgress
  attr_reader :upload_size

  def initialize(req, &block)
    @req = req
    @callback = block
    @upload_size = 0
    @io = req.body_stream
    req.body_stream = self
  end

  def readpartial(maxlen, outbuf)
    begin
      str = @io.readpartial(maxlen, outbuf)
    ensure
      @callback.call(self) unless @upload_size.zero?
    end
    @upload_size += str.length
    str
  end
end
