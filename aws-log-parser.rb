#!/usr/bin/env ruby

#
# usage:
#   aws-log-parser.rb --fields="requestid tstamp req" path/to/file.log
# or via stdin
#   aws-log-parser.rb --fields="requestid tstamp req" < path/to/file.log
# with default fields:
#   aws-log-parser.rb < path/to/file.log
#

require 'slop'

# example
# log/path/is/long.out i-01633 [example.gov] [5c6e6b44-089a-4958-9bc5-ae5ce1607cdf] [172.30.86.122] [USERID user@example.gov] [2019-04-10 10:35:27 -0400]

pattern = /^(\S+)\ (\S+)\ \[(.+?)\]\ \[(.+?)\]\ \[(.+?)\]\ (\[(.+?)\]\ )?\[(.+?)\]\ +(.+)/

opts = Slop.parse do |o|
  o.array '-f', '--fields', 'list of fields to show', default: ['requestid', 'tstamp', 'req'], delimiter: /\W/
end

template = opts[:fields].map(&:to_sym)

puts template.inspect

# make sure sloptions aren't consumed by ARGF
ARGV.replace opts.arguments

ARGF.each_line do |line|
  parts = line.match(pattern)
  #puts "line: #{line}"
  next unless parts
  #puts "parts: #{parts.captures.inspect}"
  logf, ec2id, hostname, requestid, ipaddr, user_bracket, user, tstamp, req = parts.captures
  rec = { logf: logf, ec2id: ec2id, hostname: hostname, requestid: requestid, ipaddr: ipaddr, user: user, tstamp: tstamp, req: req }
  out = []
  template.each do |field|
    out << "[#{rec[field]}]"
  end
  puts out.join(" ")
end
