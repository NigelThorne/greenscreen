require 'rubygems'
require 'sinatra'
require 'erb'
require 'rexml/document'
require 'hpricot'
require 'open-uri'
require 'nokogiri'

get '/' do
  servers = YAML.load_file 'config.yml'
  return "Add the details of build server to the config.yml file to get started" unless servers
  
  @projects = []

  servers.each do |server|
    xml = Nokogiri::HTML(open(server["url"]))#, :http_basic_authentication=>[server["username"], server["password"]]))
    projects = xml.xpath("//table[@class='tcTable']//td[@class='buildConfigurationName']/..")
    
    projects.each do |project|
      monitored_project = MonitoredProject.new(project)
      if server["jobs"]
        if server["jobs"].detect {|job| /#{job}/ =~ monitored_project.id}
          @projects << monitored_project
        end
      else
        @projects << monitored_project
      end
    end
  end

  @columns = 1.0
  @columns = 2.0 if @projects.size > 4
  @columns = 3.0 if @projects.size > 10
  @columns = 4.0 if @projects.size > 21
  
  @rows = (@projects.size / @columns).ceil
  @rows = 1 if(@rows == 0) 
  erb :index
end

class MonitoredProject
  attr_reader :name, :last_build_status, :activity, :last_build_time, :web_url, :last_build_label, :project, :id, :blame
  
  def initialize(project)
  	
  	buildConfigName = project.xpath(".//td[@class='buildConfigurationName']/a")
  	
    # @activity = project.xpath(["activity"]
    @activity = ""

  	@last_build_time = Time.parse(project.xpath(".//div[@class='teamCityDateTime']").inner_text).localtime
  	@web_url = buildConfigName.attr("href")
  	@last_build_label = project.xpath(".//div[@class='teamCityBuildNumber']").inner_text

  	@last_build_status = "success" if buildConfigName.xpath("./..//img").attr("title").value =~ /successful/
  	@last_build_status = "failure" if buildConfigName.xpath("./..//img").attr("title").value =~ /failing/
  	@last_build_status = "failure" if buildConfigName.xpath("./..//img").attr("title").value =~ /responsible/
  	@last_build_status ||= "unknown"
  	@project = project.xpath("..//div[@class='projectName']/a").inner_text
  	@name = buildConfigName.inner_text
  	@id = "#{@project}_#{@name}"
  	@blame = buildConfigName.xpath("./..//img").attr("title").value	
  	@blame = (/responsible/ =~ @blame) ? @blame.split(" is ")[0] : nil
  end
end