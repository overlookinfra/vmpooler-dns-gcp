# frozen_string_literal: true

require 'googleauth'
require 'google/cloud/dns'

module Vmpooler
  class PoolManager
    class Dns
      class Gcp
        # This class represent a DNS plugin to CRUD resources in google clouddns.
        class Clouddns < Vmpooler::PoolManager::Dns::Base
          # The connection_pool method is normally used only for testing
          attr_reader :connection_pool

          def initialize(config, logger, metrics, redis_connection_pool, name, options)
            super(config, logger, metrics, redis_connection_pool, name, options)

            task_limit = global_config[:config].nil? || global_config[:config]['task_limit'].nil? ? 10 : global_config[:config]['task_limit'].to_i

            default_connpool_size = [provided_pools.count, task_limit, 2].max
            # connpool_size = provider_config['connection_pool_size'].nil? ? default_connpool_size : provider_config['connection_pool_size'].to_i
            connpool_timeout = 60
            # logger.log('d', "[#{name}] ConnPool - Creating a connection pool of size #{connpool_size} with timeout #{connpool_timeout}")
            logger.log('d', "[#{name}] ConnPool - Creating a connection pool of size #{default_connpool_size} with timeout #{connpool_timeout}")
            @connection_pool = Vmpooler::PoolManager::GenericConnectionPool.new(
              metrics: metrics,
              connpool_type: 'dns_connection_pool',
              connpool_provider: name,
              size: default_connpool_size,
              # size: connpool_size,
              timeout: connpool_timeout
            ) do
              logger.log('d', "[#{name}] Connection Pool - Creating a connection object")
              # Need to wrap the vSphere connection object in another object. The generic connection pooler will preserve
              # the object reference for the connection, which means it cannot "reconnect" by creating an entirely new connection
              # object.  Instead by wrapping it in a Hash, the Hash object reference itself never changes but the content of the
              # Hash can change, and is preserved across invocations.
              new_conn = connect_to_gcp
              { connection: new_conn }
            end
          end

          def name
            'gcp-clouddns'
          end

          def create_or_replace_record(hostname)
            ip = get_ip(hostname)
            connection.zone('vmpooler-example-com').add(hostname, 'A', 60, ip)
          end

          def connection
            @connection_pool.with_metrics do |pool_object|
              return ensured_gcp_connection(pool_object)
            end
          end

          def ensured_gcp_connection(connection_pool_object)
            connection_pool_object[:connection] = connect_to_gcp unless connection_pool_object[:connection]
            connection_pool_object[:connection]
          end

          def connect_to_gcp
            max_tries = global_config[:config]['max_tries'] || 3
            retry_factor = global_config[:config]['retry_factor'] || 10
            try = 1
            begin
              scopes = ['https://www.googleapis.com/auth/cloud-platform']
  
              Google::Auth.get_application_default(scopes)
  
              dns = Google::Cloud::Dns.new
              # dns.authorization = authorization
  
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

        end
      end
    end
  end
end
