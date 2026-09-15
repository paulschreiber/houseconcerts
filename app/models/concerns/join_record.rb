module JoinRecord
  extend ActiveSupport::Concern

  class_methods do
    # Declares the two sides of a plain join table: each belongs_to, plus
    # a uniqueness validation on the pair so the same combination can't be
    # inserted twice.
    def join_belongs_to(first, second)
      belongs_to first
      belongs_to second
      validates :"#{first}_id", uniqueness: { scope: :"#{second}_id" }
    end
  end
end
