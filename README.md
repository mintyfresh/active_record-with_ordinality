# ActiveRecord::WithOrdinality

Joins lists of values to ActiveRecord relations with their ordinal positions,
and orders relations by them with `in_order_of`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record-with_ordinality', github: 'mintyfresh/active_record-with_ordinality'
```

And then execute:

```bash
$ bundle
```

Then extend your models with `ActiveRecord::WithOrdinality` (typically in `ApplicationRecord`, so all models get it):

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  extend ActiveRecord::WithOrdinality
end
```

## Usage

### with_ordinality

`with_ordinality` joins a list of values to the records with matching columns,
along with the position of each value (starting from 1):

```ruby
User.with_ordinality(:id, [3, 1, 2])
# SELECT "users".* FROM "users"
# INNER JOIN (
#   SELECT (element.value->>0)::bigint AS "id", element.ordinality AS "ordinal"
#   FROM json_array_elements('[[3],[1],[2]]'::json) WITH ORDINALITY AS element(value, ordinality)
# ) AS "users_id_ordinals" ON "users"."id" = "users_id_ordinals"."id"
# WHERE "users"."id" IN (3, 1, 2)
```

The ordinal is selected onto the records when it's given a name with `as`:

```ruby
User.with_ordinality(:id, [3, 1, 2], as: :position).map { |user| [user.id, user.position] }
# => [[1, 2], [2, 3], [3, 1]]
```

Otherwise, it can be used in the rest of the query by the name of the joined table
(which defaults to the table and columns, eg. `users_id_ordinals`, or can be given with `join_table_name`):

```ruby
User.with_ordinality(:id, [3, 1, 2]).order('users_id_ordinals.ordinal')
User.with_ordinality(:id, [3, 1, 2], join_table_name: :positions).order('positions.ordinal')
```

Only records matching the values are kept, unless `filter` is false (in which case other records have no ordinal):

```ruby
User.with_ordinality(:id, [3, 1], as: :position, filter: false)
```

Repeated values are joined once, at their first position, so that records aren't repeated.
Values are converted by the types of the attributes, so eg. enums can be given by name.

### Composite columns

Several columns can be given, with a list of values for each record:

```ruby
User.with_ordinality(%i[tenant_id id], [[1, 3], [1, 1], [1, 2], [2, 4]], as: :position)
```

### in_order_of

`in_order_of` is overridden to order records by their ordinals, rather than by a `CASE` of every value,
and supports composite columns:

```ruby
User.in_order_of(:id, [3, 1, 2])
User.in_order_of(%i[tenant_id id], [[1, 3], [1, 1], [1, 2], [2, 4]])
User.in_order_of(:id, [3, 1, 2], filter: false) # other records are ordered last
```

Columns that aren't attributes of the model (eg. `Arel.sql('LOWER(name)')`) are ordered by Rails' `in_order_of`.

### Databases

PostgreSQL (`json_array_elements` with `WITH ORDINALITY`), MySQL (`JSON_TABLE` with `FOR ORDINALITY`),
and SQLite (`json_each`) are supported.

### Sorbet

A Tapioca DSL compiler is included, which adds `with_ordinality` to the relations generated for models
extended by `ActiveRecord::WithOrdinality`. It's loaded automatically by `bin/tapioca dsl`.

## Development

The specs run against a dummy Rails application in `spec/dummy`, using SQLite by default:

```bash
$ bin/rspec
$ bin/rubocop
```

PostgreSQL and MySQL are selected with the `DATABASE_ADAPTER` and `DATABASE_URL` environment variables
(see `.github/workflows/ci.yml`).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
