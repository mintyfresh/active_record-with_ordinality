# frozen_string_literal: true

require 'rails_helper'
require 'tapioca/dsl/compilers/active_record_with_ordinality'

RSpec.describe Tapioca::Dsl::Compilers::ActiveRecordWithOrdinality do
  subject(:rbi) do
    Tapioca::Dsl::Pipeline.new(requested_constants: [User], requested_compilers:, number_of_workers: 1)
      .run { |_constant, file| Tapioca::DEFAULT_RBI_FORMATTER.print_file(file) }
      .first
  end

  let(:requested_compilers) { [Tapioca::Dsl::Compilers::ActiveRecordRelations, described_class] }
  let(:parameter_types) do
    'column_names: T.any(Symbol, String, T::Array[T.any(Symbol, String)]), ' \
      'values: T::Enumerable[T.untyped], ' \
      'as: T.nilable(T.any(Symbol, String)), ' \
      'filter: T::Boolean, ' \
      'join_table_name: T.nilable(T.any(Symbol, String))'
  end

  it 'adds with_ordinality to the relation methods' do
    expect(rbi.scan(/^ *def with_ordinality\(.*$/).map(&:strip)).to eq(
      ['def with_ordinality(column_names, values, as: nil, filter: true, join_table_name: nil); end'] * 2
    )
  end

  it 'types with_ordinality by the relation it returns', :aggregate_failures do
    expect(rbi).to include("sig { params(#{parameter_types}).returns(PrivateRelation) }")
    expect(rbi).to include("sig { params(#{parameter_types}).returns(PrivateAssociationRelation) }")
  end

  it 'adds the methods to the generated relation modules', :aggregate_failures do
    expect(rbi).to match(/module GeneratedRelationMethods\b(?:(?!^  end).)*def with_ordinality/m)
    expect(rbi).to match(/module GeneratedAssociationRelationMethods\b(?:(?!^  end).)*def with_ordinality/m)
  end

  context 'when the ActiveRecordRelations compiler is not enabled' do
    let(:requested_compilers) { [described_class] }

    it 'generates nothing' do
      expect(rbi).to be_nil
    end
  end
end
