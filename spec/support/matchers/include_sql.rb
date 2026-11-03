# frozen_string_literal: true

# Matches the SQL of a relation containing a fragment, ignoring identifier quoting (which differs between databases).
#
#   expect(User.where.exists(:orders)).to include_sql('EXISTS (SELECT 1 FROM orders')
RSpec::Matchers.define :include_sql do |fragment|
  match do |relation|
    @actual = relation.to_sql.delete('"`')
    @actual.include?(fragment)
  end

  diffable
end
