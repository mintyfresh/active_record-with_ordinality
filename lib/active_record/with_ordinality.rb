# typed: true
# frozen_string_literal: true

require 'active_record'
require 'active_record/with_ordinality/version'

module ActiveRecord
  # Adds `with_ordinality` to the relations of a model and its subclasses, which joins a list of values to the records
  # with their ordinal positions, and overrides `in_order_of` to order records by them (rather than by a CASE):
  #
  #   class ApplicationRecord < ActiveRecord::Base
  #     extend ActiveRecord::WithOrdinality
  #   end
  #
  #   User.with_ordinality(:id, [3, 1, 2], as: :ordinal).map(&:ordinal)
  #   User.in_order_of(%i[tenant_id id], [[1, 3], [1, 1], [2, 4]])
  module WithOrdinality
    autoload :OrdinalityTable, 'active_record/with_ordinality/ordinality_table'
    autoload :RelationExtension, 'active_record/with_ordinality/relation_extension'

    class << self
      # Extends the relations of a model, and of any of its subclasses that were already defined.
      #
      #: (singleton(ActiveRecord::Base) base) -> void
      def extended(base)
        super
        [base, *base.descendants].each(&:install_with_ordinality)
      end
    end

    # See `RelationExtension#with_ordinality`.
    #
    #: (*untyped args, **untyped options) -> ActiveRecord::Relation
    def with_ordinality(*args, **options)
      all.with_ordinality(*args, **options)
    end

    # See `RelationExtension#in_order_of`.
    #
    #: (*untyped args, **untyped options) -> ActiveRecord::Relation
    def in_order_of(*args, **options)
      all.in_order_of(*args, **options)
    end

    # Rails builds the relation classes of each model as it's defined (see `ActiveRecord::Delegation::DelegateCache`),
    # so subclasses defined after the model was extended are installed here.
    #
    #: -> void
    def initialize_relation_delegate_cache
      super
      install_with_ordinality
    end

    #: -> void
    def install_with_ordinality
      ActiveRecord::Delegation.delegated_classes.each do |relation_class|
        relation_delegate_class(relation_class).include(RelationExtension)
      end
    end
  end
end
