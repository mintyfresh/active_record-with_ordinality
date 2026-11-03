# typed: true
# frozen_string_literal: true

module ActiveRecord
  module WithOrdinality
    module RelationExtension
      # Joins a list of values to the records with matching columns, along with the ordinal position of each value
      # (starting from 1). Composite columns are matched by lists of values:
      #
      #   User.with_ordinality(:id, [3, 1, 2])
      #   User.with_ordinality(%i[tenant_id id], [[1, 3], [1, 1], [2, 4]])
      #
      # Only records matching the values are kept, unless `filter` is false (in which case others have no ordinal).
      # The ordinal is selected onto the records as the attribute named by `as`, if given.
      # Otherwise it can be referred to by the joined table (eg. `users_id_ordinals.ordinal`).
      #
      # Repeated values are joined once, at their first position.
      #
      #: (
      #|   Symbol | String | Array[Symbol | String] column_names,
      #|   Enumerable[untyped] values,
      #|   ?as: (Symbol | String)?,
      #|   ?filter: bool,
      #|   ?join_table_name: (Symbol | String)?
      #| ) -> ActiveRecord::Relation
      def with_ordinality(column_names, values, as: nil, filter: true, join_table_name: nil)
        ordinality = OrdinalityTable.new(model, column_names, values, join_table_name)
        return none if filter && ordinality.values.empty?

        relation = filter ? where(ordinality.condition) : spawn
        relation = relation.joins(ordinality.join_sql(filter ? 'INNER JOIN' : 'LEFT OUTER JOIN'))
        return relation unless as

        relation = relation.select(table[Arel.star]) if relation.select_values.empty?
        relation.select(ordinality.ordinal.as(model.adapter_class.quote_column_name(as.to_s)))
      end

      # Orders the records in the order of a list of values, by joining them `with_ordinality`.
      # Composite columns are ordered by lists of values (see `with_ordinality`).
      #
      # Only records matching the values are kept, unless `filter` is false (in which case others are ordered last).
      # Columns that aren't attributes of the model (eg. SQL expressions) are ordered by Rails' `in_order_of` instead.
      #
      #: (untyped column_names, Enumerable[untyped] values, ?filter: bool) -> ActiveRecord::Relation
      def in_order_of(column_names, values, filter: true)
        return super unless OrdinalityTable.attributes?(model, column_names)

        # Rails' `in_order_of` matches no records for no values, regardless of `filter`
        values = values.to_a
        return none if values.empty?

        ordinal = OrdinalityTable.new(model, column_names, values).ordinal
        relation = with_ordinality(column_names, values, filter:)

        filter ? relation.order(ordinal.asc) : relation.order(ordinal.eq(nil), ordinal.asc)
      end
    end
  end
end
