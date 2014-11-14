require 'set'

module Listen
  # @private api
  class Record
    class SymlinkDetector
      SYMLINK_LOOP_ERROR = <<-EOS
        ** ERROR: Listen detected a duplicate directory being watched! **

        (This may be due to symlinks pointing to parent directories).

        Duplicate: %s

        which already is added as: %s

        Listen is refusing to continue, because this may likely result in
        an infinite loop.

        Suggestions:

          1) (best option) watch only directories you care about, e.g.
          either symlinked folders or folders with the real directories,
          but not both.

          2) reorganize your project so that watched directories do not
          contain symlinked directories

          3) submit patches so that Listen can reliably and quickly (!)
          detect symlinks to already watched read directories, skip
          them, and then reasonably choose which symlinked paths to
          report as changed (if any)

          4) (not worth it) help implement a "reverse symlink lookup"
          function in Listen, which - given a real directory - would
          return all the symlinks pointing to that directory

        Issue: https://github.com/guard/listen/issues/259
      EOS

      def initialize
        @real_dirs = Set.new
      end

      def verify_unwatched!(entry)
        real_path = entry.real_path
        @real_dirs.add?(real_path) || _fail(entry.sys_path, real_path)
      end

      private

      def _fail(symlinked, real_path)
        STDERR.puts format(SYMLINK_LOOP_ERROR, symlinked, real_path)

        # Note Celluloid eats up abort message anyway
        fail 'Failed due to looped symlinks'
      end
    end
  end
end
