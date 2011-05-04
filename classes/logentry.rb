class LogEntry < Struct.new(:author, :content, :tags, :timestamp)
  def to_s
    "#{author} said: #{content} at #{timestamp.asctime}"
  end
end
