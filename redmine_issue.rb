#! /usr/bin/env ruby
# -*- encoding: utf-8 -*-
# 対話型 Redmine クライアント
require 'yaml'
require 'pp'
require 'readline'
require './history'
require './redmine_client'

def handle_all(client, kind, identifier, &block) 
  offset = 0
  limit = 50
  begin 
    ret = if identifier.nil?
      client.send "get_#{kind}", offset, limit
    else 
      client.send "get_#{kind}", identifier, offset, limit
    end 
    objects = ret.first.last
    objects.each do |object|
      block.call object
    end
    offset += objects.length
  end while ret['total_count'] > offset
end

def gets_identifier
  while true
    identifier = history.readline 'project identifier '
    return identifier unless identifier.empty?
  end
end


kinds = {
  '1' => 'projects',
  '2' => 'categories',
  '3' => 'versions',
  '4' => 'users',
}
redmine = YAML.load_file './redmine.yml'
client = RedmineClient.new redmine
history = History.new
while true do
  print "[c]Create Issues\n"
  print "[u]Update Issues\n"
  print "[1]List Projects\n"
  print "[2]List Categories\n"
  print "[3]List Versions\n"
  print "[4]List Users\n"
  print "[5]List Trackers\n"
  print "[6]List Issue Statuses\n"
  print "[90]List Issues(50 issues)(alpha)\n"
  print "[q]quit\n"

  command = history.readline 'What would you like to do?[c/u/1/2/3/4/5/6/90/q]'
  case command
  when "c"
    file = history.readline 'path to issues file[./issues.tsv]'
    file = './issues.tsv' if file.empty?
    result = client.post_issues(File::expand_path(file))
    result.each do |v|
      pp v
    end
  when "u"
    file = history.readline 'path to issues file[./update_issues.tsv]'
    file = './update_issues.tsv' if file.empty?
    result = client.put_issues(File::expand_path(file))
    result.each do |v|
      pp v
    end
  when "1"
    identifier = history.readline 'project identifier(if you list all projects, input empty)[]'
    if identifier.empty? 
      handle_all(client, kinds[command], nil) do |project|
        print "#{project['id']}    #{project['name']}(#{project['identifier']})\n"
      end 
    else
      project = client.get_project identifier
      print "#{project['id']}    #{project['name']}(#{project['identifier']})\n"
    end
  when "2"
    identifier = gets_identifier
    handle_all(client, kinds[command], identifier) do |version|
      print "#{version['id']}    #{version['name']}\n"
    end 
  when "3"
    identifier = gets_identifier
    handle_all(client, kinds[command], identifier) do |category|
      print "#{category['id']}    #{category['name']}\n"
    end 
  when "4"
    handle_all(client, kinds[command], nil) do |user|
      print "#{user['id']}    #{user['firstname']} #{user['lastname']}\n"
    end 
  when "5"
    # trackers には total_count がないので
    trackers = client.get_trackers
    trackers['trackers'].each do |tracker|
      print "#{tracker['id']}    #{tracker['name']}\n"
    end 
  when "6"
    # issue_statuses には total_count がないので
    issue_statuses = client.get_issue_statuses
    issue_statuses['issue_statuses'].each do |status|
      print "#{status['id']}    #{status['name']}\n"
    end 
  when "90"
    identifier = gets_identifier
    offset = 0
    limit = 50
    issues = client.get_issues identifier, offset, limit
    issues['issues'].each do |issue|
      print "#{issue['id']}    #{issue['subject']}\n"
    end
  when "q"
    print "bye\n"
    exit
  end
  print "\n\n"
end

