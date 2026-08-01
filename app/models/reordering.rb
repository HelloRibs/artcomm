# Moves a record one step up or down within an ordered collection.
#
# Deliberately position-swapping rather than drag-and-drop: the frontend is
# plain HTML for now, and this keeps reordering working without JavaScript.
class Reordering
  DIRECTIONS = %w[up down].freeze

  def initialize(scope)
    @scope = scope
  end

  # Returns true when the record actually moved. Sitting at an end, or an
  # unrecognised direction, is a no-op rather than an error — reordering is not
  # worth failing a request over.
  def move(record, direction:)
    return false unless DIRECTIONS.include?(direction.to_s)

    records = renumber
    index = records.index { |candidate| candidate.id == record.id }
    return false unless index

    target = direction.to_s == "up" ? index - 1 : index + 1
    return false if target.negative? || target >= records.size

    swap(records[index], records[target])
    true
  end

  private
    # Collapse positions to a clean 1..n first. Ties and gaps are expected —
    # they come from the column default and from deletes — and swapping two
    # equal positions would otherwise silently do nothing.
    def renumber
      @scope.reload.to_a.each_with_index do |record, index|
        expected = index + 1
        record.update_column(:position, expected) unless record.position == expected
      end
    end

    def swap(one, other)
      @scope.klass.transaction do
        one_position = one.position
        one.update_column(:position, other.position)
        other.update_column(:position, one_position)
      end
    end
end
