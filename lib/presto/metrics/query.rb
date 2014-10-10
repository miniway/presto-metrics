require 'presto/metrics/client'
require 'pp'

module Presto
  module Metrics

  	class Query 
  		def initialize(client)
  			@client = client
  		end

  		def format_table(tbl, label:[], align:[], sep:' ')
  			# Compute col length
  			col = {}
  			label.each_with_index{|l, i| col[i] = l.length}
  			tbl.each{|row|
  				row.each_with_index {|cell, i| 
  					l = cell.to_s.size if cell 
  					l ||= 0
  					col[i] ||= l
  					col[i] = [[col[i], l].max, 150].min
  				}
  			}
  			# print label
  			line = []
  			label.each_with_index{|l, i|
  				line << l.to_s[0..col[i]].ljust(col[i])
  			}
  			puts line.join(sep)
  			tbl.each{|row|
  				line = []
  				row.each_with_index{|cell, i|
  					str = cell.to_s[0..col[i]]
  					a = align[i] || 'l'
  					case a 
  					when 'r'
  						line << str.rjust(col[i])
  					when 'l'
  						line << str.ljust(col[i])
  					else
  						line << str.ljust(col[i])
  					end
  				}
  				puts line.join(sep)
  			}
  			0
  		end

	  	def list
	  		ql = query_list
	  		tbl = ql.map {|q|
	  			s = q['session'] || {}
	  			query = q['query'].gsub(/[\t\r\n]/, ' ').gsub(/ {1,}/, ' ').strip
	  			[q['queryId'], q['elapsedTime'], q['state'], q['runningDrivers'], q['completedDrivers'], q['totalDrivers'], s['user'], s['catalog'], s['schema'], s['source'], query]
	  		}.sort_by{|row| row[0]}.reverse

	  		format_table(
	  			tbl, 
	  			:label => %w|query time state r f t user catalog schema source sql|,
	  			:align => %w|r     r    r     r r r l    l       r      l      l  |
	  		)
	  	end

	  	def find(queryId)
	  		JSON.parse(@client.get_query_json(queryId, "{}"))
	  	end

	  	def task_list(queryId)
	  		qj = find(queryId) || {}
        root_stage = qj['outputStage'] || []
        tasks = root_stage['tasks'] || []
        tasks << find_tasks(root_stage['subStages'])
        tasks.flatten
      end

      def tasks(queryId)
        tl = task_list(queryId)
        stats = tl.map {|t|
          s = t['stats']
          [t['taskId'], s['processedInputPositions'], s['outputPositions'], s['outputDataSize']]
        }
        format_table(stats,
                     :label => %w|task_id input_pos output_pos output_size|,
                     :align => %w|l       r         r          r|
        )
      end

	  	def query_list(path="")
	  		JSON.parse(@client.get_query_json(path))
	  	end

	  	def metrics 
	  		ql = query_list
	  		ql.map{|qi|
	  			h = {}
	  			h['query_id'] = qi['queryId'] || ''
	  			h['state'] = qi['state'] || ''
	  			session = qi['session'] || {}
	  			h['source'] = session['source'] || ''
	  			h['user'] = session['user'] || h['source'].gsub(/[^a-zA-Z0-9]/,'')
	  			h['running_drivers'] = qi['runningDrivers'] || 0
	  			h['queued_drivers'] = qi['queuedDrivers'] || 0
	  			h['completed_drivers'] = qi['completedDrivers'] || 0
	  			h['total_drivers'] = qi['totalDrivers'] || 0
	  			h['elapsed_time'] = qi['elapsedTime'] || '0.0m'
	  			h['create_time'] = qi['createTime']
	  			h['running_time'] = qi['endTime'] || Time.now.utc.iso8601(3)
	  			#if(h['state'] == "FAILED")
	  			#	h['errorCode'] = find(h['query_id'])['errorCode'] || {}
	  			#end
	  			h
	  		}
	  	end

    end

    private

    def find_tasks(sub_stages)
      task_list = []
      return task_list unless sub_stages
      sub_stages.each{|ss|
        tl = ss['tasks']
        task_list << tl if tl
        task_list << find_tasks(ss['subStages'])
      }
      task_list.flatten()
    end

  end
end