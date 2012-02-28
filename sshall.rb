#!/usr/bin/env ruby
require 'pp'
require 'rubygems'
require 'net/ssh'
require 'girl_friday'
require 'net/ssh/proxy/command'
require 'terminal-table'
require 'ipaddr'
require 'term/ansicolor'

class String; include Term::ANSIColor; end

def usage
    print """Usage : sshall.rb <ip_start> <ip_end>
      * ip_start : first ip of the range you want to check
      * ip_end : last ip of the range you want to check
    The program will compute the IP range starting at <ip_start> to <ip_end> and check all if each IP is reachable over ssh.
    You can pass some parameters as environment variable :
      * THREADS : number of concurrent threads to check the hosts (default 1)
      * COLS : number of colons (default 3)
      * MAXWAIT : time to wait before exiting (default 300, in second), set it to -1 to loop endlessly
      * SSHUSER : ssh user (default root)
      * PASS : ssh user password (will only be used for hosts, not for the gateway (default bonfire)
      * GWUSER : ssh user for the gateway (default root)
      * GATEWAY : ssh gateway to use (default none)"""
      exit 1
end

usage unless ARGV.length == 2

threads = (ENV['THREADS'] || 1).to_i
nbcols = (ENV['COLS'] || 3).to_i
maxwait = (ENV['MAXWAIT'] || 300).to_i
sshuser = (ENV['SSHUSER'] || 'root').to_s
sshgatewayuser = (ENV['GWUSER'] || 'root').to_s
sshpass = (ENV['PASS'] || 'bonfire').to_s
sshgateway = (ENV['GATEWAY'] || nil)

ip_begin = IPAddr.new(ARGV[0])
ip_end = IPAddr.new(ARGV[1])

result = {}
ip_list = (ip_begin..ip_end)
b = ip_begin.to_s.split('.')
e = ip_end.to_s.split('.')
keep_bytes = 3
3.times { |i| keep_bytes -= 1 if b[i] == e [i] }

ip_list.each do |ip|
    result[ip.to_s] = "#{ip.to_s.split('.')[3 - keep_bytes..3].join('.').red}"
end


def chunk_array(array, cols=3)
    result = [] 
    array.each_slice(cols).each { |s| result += [Hash[*s.flatten]] }
    result
end

proxy = sshgateway != nil ? Net::SSH::Proxy::Command.new("ssh #{sshgatewayuser}@#{sshgateway} 'nc %h %p'") : nil
batch = GirlFriday::Batch.new(nil, :size => threads) do |payload|
    _host = payload[:host].split('.')[3 - keep_bytes..3].join('.')
    begin
        Net::SSH.start(payload[:host], sshuser, :password => sshpass, :proxy => proxy , :timeout => 5 ) do |session|
            r = session.exec!('uptime')
            result[payload[:host]] = "\033[32m#{_host}\033[0m"
        end
    rescue Timeout::Error, Net::SSH::Disconnect 
        result[payload[:host]] = "\033[31m#{_host}\033[0m"
    rescue => e
        p "Something happen during connection to #{payload[:host]}, error is : #{e.message} #{e.inspect}"
    end
end

ip_list.each do |ip|
    batch.push({
        :host => ip.to_s
    })
end

Thread.new {
    start = Time.now()
    while (Time.now() - maxwait < start) or maxwait < 0
        rows = []
        chunk_array(result, nbcols).each do |c|
            rows << [""] + c.values + [""] * (nbcols - c.length)
        end
        print "\e[2J\e[f"
        table = Terminal::Table.new(
            :rows => rows,
            :title => "Status of IPs"
        )
        p table
        sleep(2)
    end
}

batch.results
