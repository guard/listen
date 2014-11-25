require 'set'

module Listen
  # @private api
  class Record
    class SymlinkDetector
      SYMLINK_LOOP_ERROR = <<-EOS
        ** ERROR: Listen detected a duplicate directory being watched! **

        (This may be due to multiple symlinks pointing to already watched dirs).

        Duplicate: %s

        which already is added as: %s

        Listen is refusing to continue, because it may cause an infinite loop,
        a crash or confusing results.

        Suggestions:

          1) (best option) watch only directories you care about (e.g.
          either symlinked folders or folders with the real directories,
          but not both).

          IMPORTANT: The `:ignore` options DO NOT HELP here
          (see: https://github.com/guard/listen/issues/274)

          NOTE: If you are using Listen through some other application
          (like Guard, Compass, Jekyll, Vagrant), check the documentation on
          selecting watched directories (e.g. Guard has a `-w` option, Compass
          allows you to specify multiple input/output directories, etc.)

          2) Downgrade to the 2.7.x listen gem. You can lock this into your
          Gemfile:

            gem "listen", "~> 2.7"

          IMPORTANT: Version 2.8 fixes performance and reliability issues
          present in 2.7 (see: https://github.com/guard/listen/pull/273)

          3) reorganize your project so that watched directories do not
          contain symlinked directories

          4) submit patches so that Listen can reliably and quickly (!)
          detect symlinks to already watched read directories, skip
          them, and then reasonably choose which symlinked paths to
          report as changed (if any)

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
