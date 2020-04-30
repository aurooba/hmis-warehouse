Rails.logger.info "Running initializer in #{__FILE__}"

# This assumes you are in Rails 4 and you can pluck multiple columns

class ActiveRecord::Relation
  # pluck_in_batches:  yields an array of *columns that is at least size
  #                    batch_size to a block.
  #
  #                    Special case: if there is only one column selected than each batch
  #                                  will yield an array of columns like [:column, :column, ...]
  #                                  rather than [[:column], [:column], ...]
  # Arguments
  #   columns      ->  an arbitrary selection of columns found on the table.
  #   batch_size   ->  How many items to pluck at a time
  #   &block       ->  A block that processes an array of returned columns.
  #                    Array is, at most, size batch_size
  #
  # Returns
  #   nothing is returned from the function
  def pluck_in_batches(*columns, batch_size: 1000)
    if columns.empty?
      raise "There must be at least one column to pluck"
    end

    # the :id to start the query at
    batch_start = nil

    # It's cool. We're only taking in symbols
    # no deep clone needed
    select_columns = columns.dup

    # Find index of :id in the array
    remove_id_from_results = false

    id_index = columns.map(&:to_sym).index(primary_key.to_sym)

    # :id is still needed to calculate offsets
    # add it to the front of the array and remove it when yielding
    if id_index.nil?
      id_index = 0
      select_columns.unshift(primary_key)

      remove_id_from_results = true
    end

    loop do
      relation = self.reorder(table[primary_key].asc).limit(batch_size)
      relation = relation.where(table[primary_key].gt(batch_start)) if batch_start
      items = relation.pluck(*select_columns)

      break if items.empty?

      # Use the last id to calculate where to offset queries
      last_item = items.last
      batch_start = last_item.is_a?(Array) ? last_item[id_index] : last_item

      # Remove :id column if not in *columns
      items.map! { |row| row[1..-1] } if remove_id_from_results

      yield items

      break if items.size < batch_size
    end
  end
end
