require 'net/ftp'
require 'double_bag_ftps'
require 'json'

module JSON
  def self.parse_nil(json)
    JSON.parse(json) if json && json.length >= 2
  end
end


module Glynn
  class Ftp
    attr_reader :host, :port, :username, :password, :passive, :secure

    def initialize(host, port = 21, options = Hash.new)
      options = {:username => nil, :password => nil}.merge(options)
      @host, @port = host, port
      @username, @password = options[:username], options[:password]
      @passive, @secure = options[:passive], options[:secure]
      @ftp_klass = options[:ftp_klass]
    end

    def sync(local, distant)
      connect do |ftp|
        send_dir(ftp, local, distant)
      end
    end

    private
    def connect
      ftp_klass.open(host) do |ftp|
        ftp.passive = @passive || false
        ftp.connect(host, port)
        ftp.login(username, password)
        yield ftp
      end
    end

    def ftp_klass
      @ftp_klass ||= if secure
        DoubleBagFTPS
      else
        Net::FTP
      end
    end

    def send_dir(ftp, local, distant)
      begin
        ftp.mkdir(distant)
      rescue Net::FTPPermError
        # We don't do anything. The directory already exists.
        # TODO : this is also risen if we don't have write access. Then, we need to raise.
      end
      out_file = File.new("md5.json", "w")
      in_file = File.read("md5.json")
      md5 = { }
      Dir.foreach(local) do |file_name|
        # If the file/directory is hidden (first character is a dot), we ignore it
        next if file_name =~ /^(\.|\.\.)$/
        hashBrowns = JSON.parse_nil(in_file)
        if hashBrowns != nil
          puts hashBrowns[file_name]
        end


        if ::File.stat(local + "/" + file_name).directory?
          # It is a directory, we recursively send it
          begin
            ftp.mkdir(distant + "/" + file_name)
          rescue Net::FTPPermError
            # We don't do anything. The directory already exists.
            # TODO : this is also risen if we don't have write access. Then, we need to raise.
          end
          puts " (Directory) -> " + file_name
          send_dir(ftp, local + "/" + file_name, distant + "/" + file_name)
        else


           puts "(File) -> " + file_name + " " + Digest::MD5.hexdigest(File.read(local + "/" + file_name))
           md5[file_name] = Digest::MD5.hexdigest(File.read(local + "/" + file_name))
           ftp.putbinaryfile(local + "/" + file_name, distant + "/" + file_name)

        end
      end

      out_file.write(md5.to_json)
      out_file.close
    end

    private
    def host_with_port
      "#{host}:#{port}"
    end
  end
end
