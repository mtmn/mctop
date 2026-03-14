require 'pcaprub'
require 'thread'

class MemcacheSniffer
  attr_accessor :metrics, :semaphore

  def initialize(config)
    @source  = config[:nic]
    @port    = config[:port]
    @host    = config[:host]

    @metrics = {}
    @metrics[:calls]   = {}
    @metrics[:objsize] = {}
    @metrics[:reqsec]  = {}
    @metrics[:bw]    = {}
    @metrics[:stats]   = { :recv => 0, :drop => 0 }

    @semaphore = Mutex.new
  end

  def start
    cap = PCAPRUB::Pcap.open_live(@source, 1500, true, 100)

    @metrics[:start_time] = Time.new.to_f

    @done    = false

    if @host == ""
      cap.setfilter("port #{@port}")
    else
      cap.setfilter("host #{@host} and port #{@port}")
    end

    cap.each do |packet|
      raw_stats = cap.stats
      @metrics[:stats] = { 
        :recv => raw_stats["recv"] || 0,
        :drop => raw_stats["drop"] || 0
      }

      if packet =~ /VALUE (\S+) \S+ (\S+)/
        key   = $1
        bytes = $2
        @semaphore.synchronize do
          @metrics[:calls][key] ||= 0
          @metrics[:calls][key] += 1
          @metrics[:objsize][key] = bytes.to_i
        end
      elsif packet =~ /mg (\S+)/
        key = $1
        @semaphore.synchronize do
          @metrics[:calls][key] ||= 0
          @metrics[:calls][key] += 1
          @metrics[:objsize][key] ||= 0
        end
      elsif packet =~ /VA (\d+)/
        bytes = $1
      end

      break if @done
    end
  end

  def done
    @done = true
  end
end
