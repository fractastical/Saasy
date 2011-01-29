require 'cinch'
require 'open-uri'
require 'nokogiri'
require 'cgi'
require 'token'

class GoogleResult < Struct.new(:title, :link, :desc)
  def to_s
    CGI.unescape_html "#{title} - #{desc} (#{link})"
  end
end

class LogEntry < Struct.new(:author, :content, :tags, :timestamp)
  def to_s
    "#{author} said: #{content} at #{timestamp.asctime}"
  end
end


bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "irc.freenode.net"
    c.nick     = "Saasy"
    c.channels = ["#salesforce"]
    @messages = Array.new
    @activeLinks = Array.new
    @logEntries = Array.new
    @counter = 11
    @startTime = Time.now
    @token = Token.to_s
    @siteName = 'http://salesforce-knowledge-base.heroku.com/'
  end

  helpers do

    def google(query)
      runSearch("http://www.google.com/search?site=&source=hp&q=", query)
    end

    def salesforce(query)
      runSearch("http://www.google.com/search?site=&source=hp&q=site:salesforce.com+", query)
    end

    def appexchange(query)
      runSearch("http://www.google.com/search?site=&source=hp&q=site:appexchange.salesforce.com+", query)
    end

    def community(query)
      runSearch("http://www.google.com/search?site=&source=hp&q=site:boards.developerforce.com+", query)
    end

    def runSearch(url,query)

        url = url + CGI.escape(query)
        res = Nokogiri::HTML(open(url))
        puts "Iterating through first five Google results"

        @activeLinks = Array.new

        fullResults = res.css('h3.r')
        j = fullResults.size > 5 ? 5 : fullResults.size

        for i in 0..j 

          l = fullResults[i]
          puts l.at('a')[:href]
          puts l.at("./following::div").children.first.text
          puts l.text
          @activeLinks.push(GoogleResult.new(l.text, l.at('a')[:href], l.at("./following::div").children.first.text) )

        end

      rescue
        "No results found"
      else
        @activeLinks.first.to_s      
    end

  end

  # Maintains message que of last 1000 messages.
  on :message, // do |m|
      @counter += 1
      @messages.push(m)
      if @messages.length > 100
        @messages = @messages.drop(@messages.length - 100)
      end
      puts 'COUNT:' + @counter.to_s
      puts 'Message Queue:' + @messages.length.to_s
      puts 'LogEntry Queue:' + @logEntries.length.to_s
  end

  on :message, /^!commands/ do |m, query|
    
    User(m.user).send 'Hello. I\'m Saasy. Here\'s a list of available commands:'
    User(m.user).send '!google x : searches for x and returns the first result from Google.'
    User(m.user).send '!salesforce x : searches for x on salesforce.com and returns the first result.'
    User(m.user).send '!community x : searches for x on the community boards and returns the first result.' 
    User(m.user).send '!appexchange x : searches for x on the App Exchange and returns the first result.' 
    User(m.user).send '!dance : dance!'
    User(m.user).send '!next : Returns the next result on google for the previous search.' 
    User(m.user).send '!log @username1 @username2 #x : Logs all recent comments of username1 and username2 with tag #x.' 
    User(m.user).send '!l comment #x #y: Has Saasy log the comment with the tags #x and #y. ' 
    User(m.user).send '!search #x : Shows all log entries with the tag x ' 
    User(m.user).send '!version : Shows version history  ' 
    User(m.user).send '!uptime : Shows uptime  ' 
    User(m.user).send '!site : Shows link for site where logged messages are stored' 


  end

  on :message, /^!version/ do |m, query|
    
    User(m.user).send 'Saasy here. Version 0.3'
    User(m.user).send 'v 0.5 : Version history. Excluded tag #salesforce from logging. Message queue of last thousand messages'
    User(m.user).send 'v 0.6 : !log command. Remove logging of search'
    User(m.user).send 'v 0.65 : Search changed to !search.'
    User(m.user).send 'v 0.7 : Logging only with !l. Saasy only responds to her name every 15 posts. Fixed !log'
    User(m.user).send 'v 0.75 : !safeharbor added'
    User(m.user).send 'v 0.8 : Logs to simple-frost-403.heroku.com'
    User(m.user).send 'v 0.85 : !uptime command. Log only last 100 messages. !site. Added tags '
    User(m.user).send 'v 0.90 : Security token.'

  end

  
  on :message, /[Ss]aasy/ do |m|
        if @counter > 10
          m.reply 'Did someone call? Type "!commands" to see what I can do. '
          @counter = 0
        end
  end

  on :message, /^!dance/ do |m|
    link = 'http://salesforcechannel.com/video/SaaSy-Music-Video'
    m.reply CGI.unescape_html link
  end
  
  on :message, /^!google (.+)/ do |m, query|
    m.reply google(query)
  end

  on :message, /^!salesforce (.+)/ do |m, query|
    m.reply salesforce(query)
  end
  
  on :message, /^!community (.+)/ do |m, query|
    m.reply community(query)
  end

  on :message, /^!boards (.+)/ do |m, query|
    m.reply community(query)
  end
    
  on :message, /^!appexchange (.+)/ do |m, query|
    m.reply appexchange(query)
  end

  on :message, /^!next/ do |m, query|
    @activeLinks = @activeLinks.drop(1)
    m.reply @activeLinks.first.to_s     
  end

  on :message, /^!site/ do |m|
    m.reply  @siteName     
  end

  on :message, /^!log (.+)/ do |m, query|
    tags = query.scan(/\B#\w*[A-Za-z_]+\w*/)
    usernames = query.scan(/@[A-Za-z0-9_]+/)
    count = 0
    userString = ''
    contentString = ''


    @messages.each do |msg|
                        usernames.each do |u|
                            puts count
                            puts 'usr ' + u
                            puts 'nick ' + msg.user.nick
                            
                            if ( '@' + msg.user.nick ) == u then
                              
                                 if msg.message[/[\w\d\s\W]+/] != nil
                                   
                                   @logEntries.push(LogEntry.new(msg.user.nick, msg.message[/^[\w\d\s]+/], tags, Time.now))
                                   contentString += msg.user.nick + ': ' + msg.message[/[\w\d\s\W]+/] + '\n'
                                   count += 1

                                 end
                                 
                            end                             
                        end 
                  end
                  
    tagString = ''
    tags.each { |t| tagString += t + ' '}
    tagString = tagString[0,tagString.length - 1]
    usernames.each { |u| userString += u + ' and ' }
    userString = userString[0,userString.length - 5]          
    if count > 0    
    
        url =  @siteName + '/messages/create/'
        url += CGI.escape(userString)
        url += '/'
        url += CGI.escape(contentString)
        url += '/'
        url += CGI.escape(tagString)
        url += '/'
        url += @token

        open(url)

        puts 'pushed'

        m.reply count.to_s + ' messages logged.'
    else
        m.reply 'No messages found to log.'
    end
    
                  
  end
    

  on :message, /^!l (.+)/ do |m, query|

    tags = query.scan(/\B#\w*[A-Za-z_]+\w*/)
    #tags.delete('#salesforce')
    tagString = ''
    
    tags.each{ |x| tagString += x.to_s + ' ' }
    @logEntries.push(LogEntry.new(m.user.nick, query[/[\w\d\s\W]+/], tags, Time.now))
    msg = query[/[\w\d\s\W]+/]
    msg = msg[1,msg.length]
    
    url = @siteName + '/messages/create/'
    url += CGI.escape(m.user.nick)
    url += '/'
    url += CGI.escape(msg)
    url += '/'
    url += CGI.escape(tagString)
    url += '/'
    url += @token
      
    open(url)
    
    if tagString != ''
       m.reply 'Logged with tags ' + tagString
    end
    
  end  
  
  on :message, /^!search (.+)/ do |m, tag|
      m.reply 'Searching for tag  ' + tag
      
      @logEntries.each do |le|
        counter=0
        le.tags.each do |t|
          if t == tag
            m.reply le.to_s
          end
        end
      end
  end  

  on :message, /^!uptime/ do |m, tag|
      upTimeInMin = (Time.now - @startTime) / 60
      if(upTimeInMin < 240)
        m.reply 'Up for  ' + upTimeInMin.round(2).to_s + ' minutes'
      else
        m.reply 'Up for  ' + (upTimeInMin / 60 ).round(2).to_s + ' hours'
      end
        
  end  


  on :message, /^!safeharbor/ do |m|
      m.reply 'This channel may contain forward-looking statements that involve risks, uncertainties, and assumptions. If any such uncertainties materialize or if any of the assumptions prove incorrect, the results of salesforce.com, inc. could differ materially from the results expressed or implied by the forward-looking statements we make. All statements other than statements of historical fact could be deemed forward-looking statements, including: any projections of earnings, revenues, or other financial items; any statements regarding strategies or plans of management for future operations; any statements concerning new, planned, or upgraded services or developments; statements about current or future economic conditions; and any statements of belief. '
      m.reply 'The risks and uncertainties referred to above include - but are not limited to - risks associated with our new business model; our past operating losses; possible fluctuations in our operating results and rate of growth; interruptions or delays in our Web hosting; breach of our security measures; the immature market in which we operate; our relatively limited operating history; our ability to expand, retain, and motivate our employees and manage our growth; risks associated with new releases of our service; and risks associated with selling to larger enterprise customers. Further information on potential factors that could affect the financial results of salesforce.com, inc. are included in our registration statement (on Form S-1) and in other filings with the Securities and Exchange Commission. These documents are available on the SEC Filings section of this channel.'
      m.reply 'Salesforce.com, inc. assumes no obligation and does not intend to update these forward-looking statements.'
      m.reply 'Any unreleased services or features referenced in this or other press releases or public statements are not currently available and may not be delivered on time or at all. Customers who purchase our services should make the purchase decisions based upon features that are currently available. '
  end  
  
end

bot.start
