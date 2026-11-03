# typed: true
# frozen_string_literal: true

module ActiveRecord
  module WithOrdinality
    # A table of values (decoded from JSON by the database) numbered by their position, with the SQL to join it:
    # * PostgreSQL - `json_array_elements` with `WITH ORDINALITY`
    # * MySQL - `JSON_TABLE` with a `FOR ORDINALITY` column
    # * SQLite - `json_each`, numbered by array index
    #
    # The table has a column for each of the model's columns (of the same name and type), and an `ordinal` column.
    class OrdinalityTable
      ORDINAL_COLUMN_NAME = 'ordinal'

      class << self
        # Checks if columns are given as names of the model's attributes (rather than eg. SQL expressions).
        #
        #: (singleton(ActiveRecord::Base) model, untyped column_names) -> bool
        def attributes?(model, column_names)
          names = Array(column_names)

          names.any? && names.all? do |name|
            (name.is_a?(Symbol) || name.is_a?(String)) && model.columns_hash.key?(column_name(model, name))
          end
        end

        # Resolves aliased attributes to their columns.
        #
        #: (singleton(ActiveRecord::Base) model, Symbol | String name) -> String
        def column_name(model, name)
          model.attribute_aliases.fetch(name.to_s, name.to_s)
        end
      end

      #: String
      attr_reader :name

      # The rows of values, without repeats (which would join each record more than once).
      #
      #: Array[Array[untyped]]
      attr_reader :values

      #: (
      #|   singleton(ActiveRecord::Base) model,
      #|   Symbol | String | Array[Symbol | String] column_names,
      #|   Enumerable[untyped] values,
      #|   ?(Symbol | String)? name
      #| ) -> void
      def initialize(model, column_names, values, name = nil)
        @model = model
        @column_names = Array(column_names).map { |column_name| resolve_column_name(column_name) }
        @values = values.map { |value| column_names.is_a?(Array) ? row(value) : [value] }.uniq
        @name = (name || "#{model.table_name}_#{@column_names.join('_')}_ordinals").to_s
      end

      # Matches the records to the values, as a condition of the model's table (so that its indexes may be used).
      #
      #: -> Hash[String | Array[String], untyped]
      def condition
        @column_names.one? ? { @column_names.first => @values.map(&:first) } : { @column_names => @values }
      end

      #: -> Arel::Attributes::Attribute
      def ordinal
        Arel::Table.new(name)[ORDINAL_COLUMN_NAME]
      end

      # Joins the table to the model's table by the columns.
      #
      #: (String join_type) -> String
      def join_sql(join_type)
        @model.with_connection do |connection|
          conditions = @column_names.map do |column_name|
            "#{@model.quoted_table_name}.#{connection.quote_column_name(column_name)} = " \
              "#{connection.quote_table_name(name)}.#{connection.quote_column_name(column_name)}"
          end

          @model.sanitize_sql_array(
            ["#{join_type} #{source_sql(connection)} ON #{conditions.join(' AND ')}", ActiveSupport::JSON.encode(rows)]
          )
        end
      end

    private

      #: (Symbol | String column_name) -> String
      def resolve_column_name(column_name)
        resolved = self.class.column_name(@model, column_name)
        return resolved if @model.columns_hash.key?(resolved)

        raise ArgumentError, "`#{column_name}` is not a column of `#{@model.name}`."
      end

      #: (untyped value) -> Array[untyped]
      def row(value)
        row = Array(value)
        return row if row.size == @column_names.size

        raise ArgumentError, "Expected #{@column_names.size} values for the columns #{@column_names.inspect}, " \
                             "got #{value.inspect}."
      end

      # The values as the database stores them (eg. the integers of enums).
      #
      #: -> Array[Array[untyped]]
      def rows
        types = @column_names.map { |column_name| @model.type_for_attribute(column_name) }

        @values.map { |row| row.zip(types).map { |value, type| type.serialize(value) } }
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def source_sql(connection)
        case connection.adapter_name
        when /postgres/i then postgresql_source_sql(connection)
        when /mysql|trilogy/i then mysql_source_sql(connection)
        when /sqlite/i then sqlite_source_sql(connection)
        else
          raise NotImplementedError, "with_ordinality isn't supported by the #{connection.adapter_name} adapter."
        end
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def postgresql_source_sql(connection)
        columns = @column_names.each_with_index.map do |column_name, index|
          "(element.value->>#{index})::#{@model.columns_hash[column_name].sql_type} " \
            "AS #{connection.quote_column_name(column_name)}"
        end
        columns << "element.ordinality AS #{connection.quote_column_name(ORDINAL_COLUMN_NAME)}"

        elements = 'json_array_elements(?::json) WITH ORDINALITY AS element(value, ordinality)'

        "(SELECT #{columns.join(', ')} FROM #{elements}) AS #{connection.quote_table_name(name)}"
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def mysql_source_sql(connection)
        columns = ["#{connection.quote_column_name(ORDINAL_COLUMN_NAME)} FOR ORDINALITY"]
        columns.concat(
          @column_names.each_with_index.map do |column_name, index|
            "#{connection.quote_column_name(column_name)} #{@model.columns_hash[column_name].sql_type} " \
              "PATH '$[#{index}]'"
          end
        )

        "JSON_TABLE(?, '$[*]' COLUMNS(#{columns.join(', ')})) AS #{connection.quote_table_name(name)}"
      end

      #: (ActiveRecord::ConnectionAdapters::AbstractAdapter connection) -> String
      def sqlite_source_sql(connection)
        columns = @column_names.each_with_index.map do |column_name, index|
          "json_extract(value, '$[#{index}]') AS #{connection.quote_column_name(column_name)}"
        end
        columns << "key + 1 AS #{connection.quote_column_name(ORDINAL_COLUMN_NAME)}"

        "(SELECT #{columns.join(', ')} FROM json_each(?)) AS #{connection.quote_table_name(name)}"
      end
    end
  end
end
