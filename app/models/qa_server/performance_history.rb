# frozen_string_literal: true
# Provide access to the scenario_results_history database table which tracks specific scenario runs over time.
module QaServer
  class PerformanceHistory < ActiveRecord::Base
    self.table_name = 'performance_history'

    enum action: [:fetch, :search]

    class_attribute :stats_calculator_class, :graph_data_service_class, :graphing_service_class, :authority_list_class
    self.stats_calculator_class = QaServer::PerformanceCalculatorService
    self.graph_data_service_class = QaServer::PerformanceGraphDataService
    self.graphing_service_class = QaServer::PerformanceGraphingService
    self.authority_list_class = QaServer::AuthorityListerService

    class << self
      include QaServer::PerformanceHistoryDataKeys

      # Save a scenario result
      # @param authority [String] name of the authority
      # @param action [Symbol] type of action being evaluated (e.g. :fetch, :search)
      # @param dt_stamp [Time] defaults to current time in preferred time zone
      # @return ActveRecord::Base for the new performance history record
      def create_record(authority:, action:, dt_stamp: QaServer.current_time)
        create(dt_stamp: dt_stamp,
               authority: authority,
               action: action)
      end

      # Performance data for a day, a month, a year, and all time for each authority.
      # @param datatype [Symbol] what type of data should be calculated (e.g. :datatable, :graph, :all)
      # @returns [Hash] performance statistics for the past 24 hours
      # @example
      #   { all_authorities:
      #     { search:
      #       {
      #         datatable_stats:
      #           { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5,
      #             retrieve_10th_ms: 12.3, graph_load_10th_ms: 12.3, normalization_10th_ms: 4.2, full_request_10th_ms: 16.5,
      #             retrieve_90th_ms: 12.3, graph_load_90th_ms: 12.3, normalization_90th_ms: 4.2, full_request_90th_ms: 16.5 }
      #         day:
      #           { 0: { hour: '1400', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             1: { hour: '1500', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             2: { hour: '1600', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             ...,
      #             23: { hour: 'NOW', retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }}
      #           },
      #         month:
      #           { 0: { day: '07-15-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             1: { day: '07-16-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             2: { day: '07-17-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             ...,
      #             29: { day: 'TODAY', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }}
      #           },
      #         year:
      #           { 0: { month: '09-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             1: { month: '10-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             2: { month: '11-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }},
      #             ...,
      #             11: { month: '08-2019', stats: { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5, etc. }}
      #           }
      #       },
      #       fetch: { ... # same data as for search_stats }
      #       all: { ... # same data as for search_stats }
      #     },
      #     AGROVOC_LD4L_CACHE: { ... # same data for each authority  }
      #   }
      def performance_data(datatype: :datatable)
        return if datatype == :none
        QaServer.config.performance_cache.write_all
        data = calculate_data(datatype)
        graphing_service_class.create_performance_graphs(performance_data: data) if calculate_graphdata? datatype
        data
      end

      private

        def calculate_datatable?(datatype)
          datatype == :datatable || datatype == :all
        end

        def calculate_graphdata?(datatype)
          datatype == :graph || datatype == :all
        end

        def calculate_data(datatype)
          data = {}
          auths = authority_list_class.authorities_list
          data[ALL_AUTH] = data_for_authority(datatype: datatype)
          auths.each { |auth_name| data[auth_name] = data_for_authority(authority_name: auth_name, datatype: datatype) }
          data
        end

        def data_for_authority(authority_name: nil, datatype:)
          action_data = {}
          [:search, :fetch, :all_actions].each do |action|
            data = {}
            data[FOR_DATATABLE] = data_table_stats(authority_name, action) if calculate_datatable?(datatype)
            if calculate_graphdata?(datatype)
              data[FOR_DAY] = graph_data_service_class.average_last_24_hours(authority_name: authority_name, action: action)
              data[FOR_MONTH] = graph_data_service_class.average_last_30_days(authority_name: authority_name, action: action)
              data[FOR_YEAR] = graph_data_service_class.average_last_12_months(authority_name: authority_name, action: action)
            end
            action_data[action] = data
          end
          action_data
        end

        # Get statistics for all available data.
        # @param [String] auth_name - limit statistics to records for the given authority (default: all authorities)
        # @returns [Hash] performance statistics for the datatable during the expected time period
        # @example
        #   { retrieve_avg_ms: 12.3, graph_load_avg_ms: 2.1, normalization_avg_ms: 4.2, full_request_avg_ms: 16.5,
        #     retrieve_10th_ms: 12.3, graph_load_10th_ms: 12.3, normalization_10th_ms: 4.2, full_request_10th_ms: 16.5,
        #     retrieve_90th_ms: 12.3, graph_load_90th_ms: 12.3, normalization_90th_ms: 4.2, full_request_90th_ms: 16.5 }
        def data_table_stats(auth_name, action)
          records = records_for_last_24_hours(auth_name) ||
                    records_for_last_30_days(auth_name) ||
                    records_for_last_12_months(auth_name) ||
                    all_records(auth_name)
          stats_calculator_class.new(records, action: action).calculate_stats(avg: true, low: true, high: true)
        end

        def expected_time_period
          QaServer.config.performance_datatable_default_time_period
        end

        def records_for_last_24_hours(auth_name)
          return unless expected_time_period == :day
          end_hour = QaServer.current_time
          start_hour = end_hour - 23.hours
          where_clause = { dt_stamp: start_hour..end_hour }
          records_for_authority(auth_name, where_clause)
        end

        def records_for_last_30_days(auth_name)
          return unless expected_time_period == :month
          end_day = QaServer.current_time
          start_day = end_day - 29.days
          where_clause = { dt_stamp: start_day..end_day }
          records_for_authority(auth_name, where_clause)
        end

        def records_for_last_12_months(auth_name)
          return unless expected_time_period == :year
          end_month = QaServer.current_time
          start_month = end_month - 11.months
          where_clause = { dt_stamp: start_month..end_month }
          records_for_authority(auth_name, where_clause)
        end

        def all_records(auth_name)
          auth_name.nil? ? PerformanceHistory.all : where(authority: auth_name)
        end

        def records_for_authority(auth_name, where_clause)
          where_clause[:authority] = auth_name unless auth_name.nil?
          where(where_clause)
        end
    end
  end
end
