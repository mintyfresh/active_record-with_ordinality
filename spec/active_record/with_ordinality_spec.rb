# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveRecord::WithOrdinality do
  let!(:first) { create(:user, tenant_id: 1) }
  let!(:second) { create(:user, tenant_id: 1) }
  let!(:third) { create(:user, tenant_id: 1, status: :inactive) }
  let!(:other_tenant) { create(:user, tenant_id: 2) }

  describe '.with_ordinality' do
    it 'selects the ordinal of each record by the given name' do
      relation = User.with_ordinality(:id, [third.id, first.id], as: :ordinal)

      expect(relation.index_with(&:ordinal)).to eq(third => 1, first => 2)
    end

    it 'filters records to the values' do
      expect(User.with_ordinality(:id, [third.id, first.id])).to contain_exactly(first, third)
    end

    it 'does not select the ordinal without a name' do
      expect(User.with_ordinality(:id, [first.id]).first).not_to respond_to(:ordinal)
    end

    it 'can be ordered by the ordinal of the joined table' do
      relation = User.with_ordinality(:id, [third.id, first.id, second.id]).order('users_id_ordinals.ordinal')

      expect(relation).to eq([third, first, second])
    end

    it 'filters by the model table, so that its indexes may be used' do
      expect(User.with_ordinality(:id, [first.id])).to include_sql("WHERE users.id = #{first.id}")
    end

    it 'joins repeated values once, at their first position' do
      relation = User.with_ordinality(:id, [second.id, first.id, second.id], as: :position)

      expect(relation.index_with(&:position)).to eq(second => 1, first => 2)
    end

    it 'keeps the projection of the relation' do
      record = User.select(:id).with_ordinality(:id, [first.id], as: :ordinal).first

      expect(record.attributes).to eq('id' => first.id, 'ordinal' => 1)
    end

    it 'keeps the conditions of the relation' do
      expect(User.where(tenant_id: 2).with_ordinality(:tenant_id, [2, 1])).to contain_exactly(other_tenant)
    end

    it 'serializes values by the types of the attributes' do
      expect(User.with_ordinality(:status, %w[inactive], as: :ordinal).map(&:ordinal)).to eq([1])
    end

    it 'resolves aliased attributes' do
      expect(User.with_ordinality(:tenant, [2])).to contain_exactly(other_tenant)
    end

    context 'with composite columns' do
      it 'matches records by every column' do
        relation = User.with_ordinality(%i[tenant_id id], [[2, other_tenant.id], [2, first.id], [1, first.id]],
                                        as: :ordinal)

        expect(relation.index_with(&:ordinal)).to eq(other_tenant => 1, first => 3)
      end

      it 'raises an error for values of the wrong size' do
        expect { User.with_ordinality(%i[tenant_id id], [[1]]) }
          .to raise_error(ArgumentError, /Expected 2 values for the columns \["tenant_id", "id"\], got \[1\]/)
      end
    end

    context 'without filtering' do
      subject(:relation) { User.with_ordinality(:id, [second.id], as: :ordinal, filter: false) }

      it 'keeps records without values, without ordinals' do
        expect(relation.index_with(&:ordinal))
          .to eq(first => nil, second => 1, third => nil, other_tenant => nil)
      end

      it 'keeps every record for no values' do
        expect(User.with_ordinality(:id, [], filter: false).count).to eq(4)
      end
    end

    it 'matches no records for no values' do
      expect(User.with_ordinality(:id, [])).to be_empty
    end

    context 'with a table name' do
      it 'names the joined table' do
        expect(User.with_ordinality(:id, [first.id], join_table_name: :positions).order('positions.ordinal'))
          .to eq([first])
      end
    end

    it 'raises an error for columns that are not columns of the model' do
      expect { User.with_ordinality(:unknown, [1]) }
        .to raise_error(ArgumentError, '`unknown` is not a column of `User`.')
    end
  end

  describe '.in_order_of' do
    it 'orders records in the order of the values' do
      expect(User.in_order_of(:id, [third.id, first.id, second.id])).to eq([third, first, second])
    end

    it 'filters records to the values' do
      expect(User.in_order_of(:id, [third.id, first.id])).to eq([third, first])
    end

    it 'orders by the joined ordinals rather than by a CASE' do
      expect(User.in_order_of(:id, [first.id])).to include_sql('ORDER BY users_id_ordinals.ordinal ASC')
    end

    it 'orders records by composite columns' do
      values = [[2, other_tenant.id], [1, third.id], [2, first.id], [1, first.id]]

      expect(User.in_order_of(%i[tenant_id id], values)).to eq([other_tenant, third, first])
    end

    it 'orders records by attributes with types' do
      expect(User.in_order_of(:status, %w[inactive active]).first).to eq(third)
    end

    it 'orders records within the conditions of the relation' do
      expect(User.where(tenant_id: 1).in_order_of(:id, [other_tenant.id, second.id, first.id])).to eq([second, first])
    end

    context 'without filtering' do
      it 'orders records without values last' do
        relation = User.in_order_of(:id, [third.id, first.id], filter: false)

        expect(relation.first(2)).to eq([third, first])
      end

      it 'keeps records without values' do
        expect(User.in_order_of(:id, [third.id], filter: false).count).to eq(4)
      end
    end

    it 'matches no records for no values, as Rails does', :aggregate_failures do
      expect(User.in_order_of(:id, [])).to be_empty
      expect(User.in_order_of(:id, [], filter: false)).to be_empty
    end

    it 'orders by SQL expressions as Rails does' do
      relation = User.in_order_of(Arel.sql('users.id'), [second.id, first.id])

      expect(relation).to eq([second, first])
    end
  end

  describe 'models that are not extended' do
    let(:model) do
      Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
        self.table_name = 'users'
      end
    end

    it 'does not provide with_ordinality' do
      expect(model).not_to respond_to(:with_ordinality)
    end

    it 'keeps the in_order_of of Rails' do
      expect(model.in_order_of(:id, [first.id])).not_to include_sql('ordinals')
    end
  end
end
