module Listen
  module QueueOptimizer
    private

    def _smoosh_changes(changes)
      # TODO: adapter could be nil at this point (shutdown)
      if _adapter_class.local_fs?
        cookies = changes.group_by do |_, _, _, options|
          (options || {})[:cookie]
        end
        _squash_changes(_reinterpret_related_changes(cookies))
      else
        smooshed = { modified: [], added: [], removed: [] }
        changes.each { |_, change, path, _| smooshed[change] << path.to_s }
        smooshed.tap { |s| s.each { |_, v| v.uniq! } }
      end
    end

    def _squash_changes(changes)
      actions = changes.group_by(&:last).map do |path, action_list|
        [_logical_action_for(path, action_list.map(&:first)), path.to_s]
      end
      _log :info, "listen: raw changes: #{actions.inspect}"

      { modified: [], added: [], removed: [] }.tap do |squashed|
        actions.each do |type, path|
          squashed[type] << path unless type.nil?
        end
        _log :info, "listen: final changes: #{squashed.inspect}"
      end
    end

    def _logical_action_for(path, actions)
      actions << :added if actions.delete(:moved_to)
      actions << :removed if actions.delete(:moved_from)

      modified = actions.detect { |x| x == :modified }
      _calculate_add_remove_difference(actions, path, modified)
    end

    def _calculate_add_remove_difference(actions, path, default_if_exists)
      added = actions.count { |x| x == :added }
      removed = actions.count { |x| x == :removed }
      diff = added - removed

      # TODO: avoid checking if path exists and instead assume the events are
      # in order (if last is :removed, it doesn't exist, etc.)
      if path.exist?
        if diff > 0
          :added
        elsif diff.zero? && added > 0
          :modified
        else
          default_if_exists
        end
      else
        diff < 0 ? :removed : nil
      end
    end

    # remove extraneous rb-inotify events, keeping them only if it's a possible
    # editor rename() call (e.g. Kate and Sublime)
    def _reinterpret_related_changes(cookies)
      table = { moved_to: :added, moved_from: :removed }
      cookies.map do |_, changes|
        file = _detect_possible_editor_save(changes)
        if file
          [[:modified, file]]
        else
          not_silenced = changes.reject do |type, _, path, _|
            _silenced?(path, type)
          end
          not_silenced.map do |_, change, path, _|
            [table.fetch(change, change), path]
          end
        end
      end.flatten(1)
    end

    def _detect_possible_editor_save(changes)
      return unless changes.size == 2

      from_type = from_change = from = nil
      to_type = to_change = to = nil

      changes.each do |data|
        case data[1]
        when :moved_from
          from_type, from_change, from, _ = data
        when :moved_to
          to_type, to_change, to, _ = data
        else
          return nil
        end
      end

      return unless from && to

      # Expect an ignored moved_from and non-ignored moved_to
      # to qualify as an "editor modify"
      _silenced?(from, from_type) && !_silenced?(to, to_type) ? to : nil
    end
  end
end
