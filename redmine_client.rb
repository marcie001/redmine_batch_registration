# -*- encoding: utf-8 -*-
# redmine にチケットを登録する
require 'net/http'
require 'yaml'
require 'json'
require 'rexml/syncenumerator'

module JSONClient
  
  RESERVED_CHARACTERS = /[^a-zA-Z0-9\-\.\_\~]/

  def get(path, params = {})
    res = Net::HTTP.start(@host, @port, :use_ssl => @use_ssl) do |http|
      get = Net::HTTP::Get.new "#{path}.json" + parse_to_param_string(params)
      get.basic_auth @basic_id, @basic_password unless @basic_id.nil?
      get['X-Redmine-API-Key'] = @key
      get['Content-Type'] = 'application/json'
      http.request get
    end

    case res
    when Net::HTTPSuccess
      JSON.parse res.body
    else
      raise "#{res.class}\n#{res.body}"
    end
  end

  def post(path, params, body)
    res = Net::HTTP.start(@host, @port, :use_ssl => @use_ssl) do |http|
      post = Net::HTTP::Post.new "#{path}.json" + parse_to_param_string(params)
      post.basic_auth @basic_id, @basic_password unless @basic_id.nil?
      post.body = body
      post['X-Redmine-API-Key'] = @key
      post['Content-Type'] = 'application/json'
      http.request post
    end

    case res
    when Net::HTTPSuccess
      JSON.parse res.body
    else
      raise "#{res.class}\n#{res.body}"
    end
  end

  def put(path, params, body)
    res = Net::HTTP.start(@host, @port, :use_ssl => @use_ssl) do |http|
      put = Net::HTTP::Put.new "#{path}.json" + parse_to_param_string(params)
      put.basic_auth @basic_id, @basic_password unless @basic_id.nil?
      put.body = body
      put['X-Redmine-API-Key'] = @key
      put['Content-Type'] = 'application/json'
      http.request put
    end

    case res
    when Net::HTTPSuccess
      # res.body に何も入っていないのでリクエストのボディをハッシュにして返す
      JSON.parse body
    else
      raise "#{res.class}\n#{res.body}"
    end
  end

  def parse_to_param_string(params)
    str = params.nil? ? '' : params.map { |k, v| k.to_s + "=" + URI::escape(v.to_s, RESERVED_CHARACTERS) }.join('&')
    str.empty? ? str : '?' + str
  end
end

class RedmineClient
  include JSONClient

  #ISSUE_COLUMNS_CREATE = %w(project_id tracker_id subject description status_id priority_id assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date estimated_hours done_ratio)
  ISSUE_COLUMNS_CREATE = %w(project_id subject description assigned_to_id category_id fixed_version_id start_date due_date estimated_hours estimated_hours)
  ISSUE_COLUMNS_UPDATE = %w(issue_id project_id subject description assigned_to_id category_id fixed_version_id start_date due_date estimated_hours estimated_hours)

  def initialize(redmine)
    @host = redmine['host']
    @use_ssl = redmine['use_ssl']
    @port = @use_ssl ? 443 : 80
    @key = redmine['key']
    @basic_id = redmine['basic_id']
    @basic_password = redmine['basic_password']
  end
    
  def post_issues(file_path)
    issues = File.open(file_path, "r") do |file|
      file.readlines.select { |v| v =~ /^[^#]/ }.map do |v|
        create_issue_hash_for_create v.chomp
      end
    end

    issues.map do |issue|
      post '/issues', nil, JSON.generate(issue)
    end
  end

  def put_issues(file_path)
    issues = File.open(file_path, "r") do |file|
      file.readlines.select { |v| v =~ /^[^#]/ }.map do |v|
        create_issue_hash_for_update v.chomp
      end
    end

    issues.map do |issue|
      issue_id = issue['issue'].shift.last
      put "/issues/#{issue_id}", nil, JSON.generate(issue)
    end
  end

  # プロジェクトを返す。
  def get_projects(offset = 0, limit = 100)
    get '/projects', :offset => offset, :limit => limit
  end

  # ユーザを返す。
  def get_users(offset = 0, limit = 100)
    get '/users', :offset => offset, :limit => limit
  end

  # トラッカーを返す。
  def get_trackers(offset = 0, limit = 100)
    get '/trackers', :offset => offset, :limit => limit
  end

  # 状態を返す。
  def get_issue_statuses(offset = 0, limit = 100)
    get '/issue_statuses', :offset => offset, :limit => limit
  end

  # ==== Args
  # _identifier_:: プロジェクトの識別子またはid
  # ==== Return
  # 指定されたプロジェクト
  def get_project(identifier = '')
    raise 'identifier is empty.' if identifier.empty?
    get "/projects/#{identifier.to_s}"
  end

  # ==== Args
  # _identifier_:: プロジェクトの識別子またはid
  # ==== Return
  # 指定されたプロジェクトに定義されているカテゴリ
  def get_categories(identifier = '', offset = 0, limit = 100)
    raise 'identifier is empty.' if identifier.empty?
    get "/projects/#{identifier.to_s}/issue_categories", :offset => offset, :limit => limit
  end

  # ==== Args
  # _identifier_:: プロジェクトの識別子またはid
  # ==== Return
  # 指定されたプロジェクトに定義されているバージョン
  def get_versions(identifier = '', offset = 0, limit = 100)
    raise 'identifier is empty.' if identifier.empty?
    get "/projects/#{identifier.to_s}/versions", :offset => offset, :limit => limit
  end

  # ==== Args
  # _identifier_:: プロジェクトの識別子またはid
  # ==== Return
  # 指定されたプロジェクトのチケット
  def get_issues(identifier = '', offset = 0, limit = 100)
    raise 'identifier is empty.' if identifier.empty?
    get "/projects/#{identifier.to_s}/issues", :offset => offset, :limit => limit
  end

  private 
  def create_issue_hash_for_create(line)
    {"issue" => Hash[REXML::SyncEnumerator.new(ISSUE_COLUMNS_CREATE, line.split("\t")).map { |k, v| [k, v] }]}
  end

  def create_issue_hash_for_update(line)
    h = REXML::SyncEnumerator.new(ISSUE_COLUMNS_UPDATE, line.split("\t")).map { |k, v| [k, v] }
    {"issue" => Hash[h.select { |k, v| !v.nil? && !v.empty? }]}
  end
end
