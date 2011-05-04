class GoogleResult < Struct.new(:title, :link, :desc)
  def to_s
    CGI.unescape_html "#{title} - #{desc} (#{link})"
  end
end
