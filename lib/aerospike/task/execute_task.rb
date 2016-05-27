# Copyright 2013-2014 Aerospike, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Aerospike

	private

	# ExecuteTask is used to poll for long running server execute job completion.
	class ExecuteTask < Task

		# NewExecuteTask initializes task with fields needed to query server nodes.
		def initialize(cluster, statement)
			super(cluster, false)

			@task_id = statement.task_id
			@scan = statement.is_scan?

			self
		end

		# IsDone queries all nodes for task completion status.
		def all_nodes_done?

			if @scan
				command = 'scan-list'
			else
				command = 'query-list'
			end

			nodes = @cluster.nodes
			done = false

			nodes.each do |node|
				conn = node.get_connection(0)
				responseMap, err = Info.request(conn, command)
				node.put_connection(conn)

				response = responseMap[command]
				find = "job_id=#{@task_id}:"
				index = response.index(find)

				unless index
					# don't return on first check
					done = true
					next
				end

				b = index + find.length
				response = response[b, response.length]
				find = 'job_status='
				index = response.index(find)

				next unless index

				b = index + find.length
				response = response[b, response.length]
				e = response.index(':')
				status = response[0, e]

				case status
				when 'ABORTED'
					raise raise Aerospike::Exceptions::QueryTerminated
				when 'IN PROGRESS'
					return false
				when 'DONE'
					done = true
				end
			end

			done
		end

	end
end