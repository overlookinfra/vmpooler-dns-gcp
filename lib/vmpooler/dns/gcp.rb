# frozen_string_literal: true

require 'googleauth'
require 'google/cloud/dns'
require 'vmpooler/dns/base'

module Vmpooler
  class PoolManager
    class Dns
      # This class represent a DNS plugin to CRUD resources in Google Cloud DNS.
      class Gcp < Vmpooler::PoolManager::Dns::Base
        # The connection_pool method is normally used only for testing
        attr_reader :connection_pool

        def initialize(config, logger, metrics, redis_connection_pool, name, options)
          super(config, logger, metrics, redis_connection_pool, name, options)

          task_limit = global_config[:config].nil? || global_config[:config]['task_limit'].nil? ? 10 : global_config[:config]['task_limit'].to_i

          default_connpool_size = [provided_pools.count, task_limit, 2].max
          connpool_timeout = 60
          logger.log('d', "[#{name}] ConnPool - Creating a connection pool of size #{default_connpool_size} with timeout #{connpool_timeout}")
          @connection_pool = Vmpooler::PoolManager::GenericConnectionPool.new(
            metrics: metrics,
            connpool_type: 'dns_connection_pool',
            connpool_provider: name,
            size: default_connpool_size,
            timeout: connpool_timeout
          ) do
            logger.log('d', "[#{name}] Connection Pool - Creating a connection object")
            # Need to wrap the GCP connection object in another object. The generic connection pooler will preserve
            # the object reference for the connection, which means it cannot "reconnect" by creating an entirely new connection
            # object.  Instead by wrapping it in a Hash, the Hash object reference itself never changes but the content of the
            # Hash can change, and is preserved across invocations.
            new_conn = connect_to_gcp
            { connection: new_conn }
          end
        end

        def name
          'gcp'
        end

        # main configuration options
        def project
          dns_config['project']
        end

        def zone_name
          dns_config['zone_name']
        end

        def create_or_replace_record(hostname)
          retries = 0
          ip = get_ip(hostname)
          if ip.nil?
            debug_logger("An IP Address was not recorded for #{hostname}")
          else
            begin
              change = connection.zone(zone_name).add(hostname, 'A', 60, ip)
              debug_logger("#{change.id} - #{change.started_at} - #{change.status} DNS address added") if change
            rescue Google::Cloud::AlreadyExistsError => _e
              # the error is Google::Cloud::AlreadyExistsError: alreadyExists: The resource 'entity.change.additions[0]' named 'instance-8.test.vmpooler.net. (A)' already exists
              # the error is Google::Cloud::AlreadyExistsError: alreadyExists: The resource 'entity.change.additions[0]' named 'instance-8.test.vmpooler.net. (A)' already exists
              change = connection.zone(zone_name).replace(hostname, 'A', 60, ip)
              debug_logger("#{change.id} - #{change.started_at} - #{change.status} DNS address previously existed and was replaced") if change
            rescue Google::Cloud::FailedPreconditionError => e
              debug_logger("DNS create failed, retrying error: #{e}")
              sleep 5
              retry if (retries += 1) < 30
            end
          end
        end

        def delete_record(hostname)
          retries = 0
          begin
            connection.zone(zone_name).remove(hostname, 'A')
          rescue Google::Cloud::FailedPreconditionError => e
            # this error was experienced intermittently, will retry to see if it can complete successfully
            # the error is Google::Cloud::FailedPreconditionError: conditionNotMet: Precondition not met for 'entity.change.deletions[1]'
            debug_logger("GCP DNS delete_record failed, retrying error: #{e}")
            sleep 5
            retry if (retries += 1) < 30
          end
        end

        def connection
          @connection_pool.with_metrics do |pool_object|
            return ensured_gcp_connection(pool_object)
          end
        end

        def ensured_gcp_connection(connection_pool_object)
          connection_pool_object[:connection] = connect_to_gcp unless gcp_connection_ok?(connection_pool_object[:connection])
          connection_pool_object[:connection]
        end

        def gcp_connection_ok?(connection)
          _result = connection.id
          true
        rescue StandardError
          false
        end

        def connect_to_gcp
          max_tries = global_config[:config]['max_tries'] || 3
          retry_factor = global_config[:config]['retry_factor'] || 10
          try = 1
          begin
            Google::Cloud::Dns.configure do |config|
              config.project_id = project
            end

            dns = Google::Cloud::Dns.new

            metrics.increment('connect.open')
            dns
          rescue StandardError => e
            metrics.increment('connect.fail')
            raise e if try >= max_tries

            sleep(try * retry_factor)
            try += 1
            retry
          end
        end

        # used in local dev environment, set DEBUG_FLAG=true
        # this way the upstream vmpooler manager does not get polluted with logs
        def debug_logger(message, send_to_upstream: false)
          # the default logger is simple and does not enforce debug levels (the first argument)
          puts message if ENV['DEBUG_FLAG']
          logger.log('[g]', message) if send_to_upstream
        end
      end
    end
  end
end
