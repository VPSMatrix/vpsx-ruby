require 'yaml'

class Config

  def initialize
    @file_path = "vpsx.yml"
    unless File.exists? @file_path
      Dir.mkdir "config" unless Dir.exists? "config"
      File.open(@file_path, 'w') do |file|
        file.write "comment: 'Config file for VPS Matrix services'"
      end
    end
    @content = YAML::load_file(@file_path)
  end

  def content
    @content
  end

  # how to write with nested keys
  def write key, value
    @content[key] = value
    File.open(@file_path, 'w') { |f| YAML.dump(@content, f) }
  end
end