# -*- encoding: UTF-8 -*-
require 'readline'

# Readline::HISTORY のユーティリティクラス
class History
  attr_reader :file

  def initialize(file = "~/.redmine_issue_history")
    @saved_lines = 0
    @file = File.expand_path file
    self.load
  end

  #
  # load histories
  #
  def load
    return unless File.exist? @file
    File.open(@file, 'r') do |f|
      f.each_line do |l|
        l = l.chomp
        Readline::HISTORY << l.chomp unless l.empty?
      end
    end
    @saved_lines = Readline::HISTORY.length
  end

  #
  # save histories
  #
  def save
    File.open(@file, 'a') do |f|
      Readline::HISTORY[@saved_lines..-1].each do |l|
        f << l + "\n"
      end
    end
  end

  #
  # readline. add history if input is not empty.
  #
  def readline(message = '> ')
    input = Readline.readline(message, false).strip
    Readline::HISTORY << input unless input.empty?
    input
  end
end
