require 'open-uri'
require 'nokogiri'

class NewsPlugin < PazudoraPluginBase
  SEP = " | "
  PDX = "http://www.puzzledragonx.com/"

  def self.aliases
    ['news']
  end

  def self.helpstring
    "!pad news: displays last known news bulletin from PDX"
  end

  def tick(current_time, channels)
    last_headline = get_log.last
    parse_pdx
    binding.pry
    if last_headline[:headline] != get_log.last[:headline]
      registered = registered_users
      channels.each do |channel|
        channel.users.each do |u|
          if registered.include?(User.fuzzy_lookup(u.nick))
            u.send "PDX has posted a new headline: #{get_log.last[:headline]}"
          end
        end
      end
    end
  end

  def respond(m,args)
    if args == "parse"
      parse_pdx
      m.reply "Done!"
    if args == "register"
      user = User.fuzzy_lookup(m.user.nick)
      m.reply "You're not registered with Asterbot" and return unless user
      user.add_plugin_registration(NewsPlugin)
      m.reply "OK, registered."
    elsif args.to_i > 0
      n = args.to_i
      all_news = get_log
      return unless (all_news.length >= n && n < 8)
      start = -1 - n + 1
      all_news[start..-1].each do |news|
        m.reply(news[:headline] + "(#{news[:url]})")
      end
    else
      m.reply(get_log.last[:headline] + "(#{get_log.last[:url]})")
    end
  end

  def parse_pdx
    known_headlines = get_log.map{|h| h[:headline]}
    write_cache = []
    page = Nokogiri::HTML.parse(open(PDX))
    news_table = page.xpath("//table[@id='event']").detect{|t| t.to_s.include? "News"}
    news_table.children[1..-1].each do |news|
      link = news.children[2].children.first
      headline = link.children.first.to_s
      headline = headline.split(" * New").first
      url = PDX + link.attributes["href"].value
      unless known_headlines.include? headline
        write_cache << {:time => Time.now, :headline => headline, :url => url}
      end
    end
    write_cache.reverse.each do |news|
      write_to_log(news[:time], news[:headline], news[:url])
    end
  end

  def get_log
    f = File.new('data/headlines', 'r')
    posts = f.read.split("\n")
    posts.map do |rawstring|
      epoch, headline, url = rawstring.split(SEP)
      time = Time.at(epoch.to_i)
      {:time => time, :headline => headline, :url => url}
    end
  end

  def write_to_log(time, headline, url)
    f = File.new('data/headlines', 'a+')
    f.write("#{time.to_i}" + SEP + headline + SEP + url + "\n")
    f.close
  end
end