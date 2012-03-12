# Adapter watch
#
# @param [Listen::Listener] listener the adapter listener
# @param [String] path the path to watch
#
def watch(listener, path)
  callback = lambda { |changed_dirs, options| @called = true; listener.on_change(changed_dirs, options) }
  @adapter = Listen::Adapter.select_and_initialize(path, { :latency => ENV["TEST_LATENCY"].to_f }, &callback)

  sleep ENV["TEST_LATENCY"].to_f + 0.2 # manage adapter latency
  t = Thread.new { @adapter.start }
  sleep 0.1 # wait for adapter to start
  yield
  sleep ENV["TEST_LATENCY"].to_f + 0.2 # manage adapter latency
ensure
  @adapter.stop unless @adapter.is_a?(Listen::Adapters::Darwin)
  Thread.kill(t)
end

shared_examples_for 'an adapter that call properly listener#on_change' do |*args|
  options = (args.first && args.first.is_a?(Hash)) ? args.first : {}
  let(:listener) { mock(Listen::Listener) }
  before { described_class.stub(:work?) { true } }

  context 'single file operations' do
    context 'when a file is created' do
      it 'detects the added file' do
        fixtures do |path|
          if options[:recursive]
            listener.should_receive(:on_change).once.with([path], :recursive => true)
          else
            listener.should_receive(:on_change).once.with([path], {})
          end

          watch(listener, path) do
            touch 'new_file.rb'
          end
        end
      end

      context 'given a new created directory' do
        it 'detects the added file' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with do |array, options|
                array.should =~ [path, "#{path}/a_directory"]
              end
            end

            watch(listener, path) do
              mkdir 'a_directory'
              # Needed for INotify, because of :recursive rb-inotify custom flag?
              sleep 0.05 if @adapter.is_a?(Listen::Adapters::Linux)
              touch 'a_directory/new_file.rb'
            end
          end
        end
      end

      context 'given an existing directory' do
        it 'detects the added file' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with(["#{path}/a_directory"], {})
            end

            mkdir 'a_directory'

            watch(listener, path) do
              touch 'a_directory/new_file.rb'
            end
          end
        end
      end
    end

    context 'when a file is modified' do
      it 'detects the modified file' do
        fixtures do |path|
          if options[:recursive]
            listener.should_receive(:on_change).once.with([path], :recursive => true)
          else
            listener.should_receive(:on_change).once.with([path], {})
          end

          touch 'existing_file.txt'

          watch(listener, path) do
            touch 'existing_file.txt'
          end
        end
      end

      context 'given a hidden file' do
        it 'detects the modified file' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with([path], {})
            end

            touch '.hidden'

            watch(listener, path) do
              touch '.hidden'
            end
          end
        end
      end

      unless options[:adapter] == :windows
        context 'given a file mode change' do
          it 'does not detect the mode change' do
            fixtures do |path|
              if options[:recursive]
                listener.should_receive(:on_change).once.with([path], :recursive => true)
              else
                listener.should_receive(:on_change).once.with([path], {})
              end

              touch 'run.rb'

              watch(listener, path) do
                chmod 0777, 'run.rb'
              end
            end
          end
        end
      end

      context 'given an existing directory' do
        it 'detects the modified file' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with(["#{path}/a_directory"], {})
            end

            mkdir 'a_directory'
            touch 'a_directory/existing_file.txt'

            watch(listener, path) do
              touch 'a_directory/existing_file.txt'
            end
          end
        end
      end
    end

    context 'when a file is moved' do
      it 'detects the file move' do
        fixtures do |path|
          if options[:recursive]
            listener.should_receive(:on_change).once.with([path], :recursive => true)
          else
            listener.should_receive(:on_change).once.with([path], {})
          end

          touch 'move_me.txt'

          watch(listener, path) do
            mv 'move_me.txt', 'new_name.txt'
          end
        end
      end

      context 'given an existing directory' do
        it 'detects the file move into the directory' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with do |array, options|
                array.should =~ [path, "#{path}/a_directory"]
              end
            end

            mkdir 'a_directory'
            touch 'move_me.txt'

            watch(listener, path) do
              mv 'move_me.txt', 'a_directory/move_me.txt'
            end
          end
        end

        it 'detects a file move out of the directory' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with do |array, options|
                array.should =~ [path, "#{path}/a_directory"]
              end
            end

            mkdir 'a_directory'
            touch 'a_directory/move_me.txt'

            watch(listener, path) do
              mv 'a_directory/move_me.txt', 'i_am_here.txt'
            end
          end
        end

        it 'detects a file move between two directories' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with do |array, options|
                array.should =~ ["#{path}/from_directory", "#{path}/to_directory"]
              end
            end

            mkdir 'from_directory'
            touch 'from_directory/move_me.txt'
            mkdir 'to_directory'

            watch(listener, path) do
              mv 'from_directory/move_me.txt', 'to_directory/move_me.txt'
            end
          end
        end
      end
    end

    context 'when a file is deleted' do
      it 'detects the file removal' do
        fixtures do |path|
          if options[:recursive]
            listener.should_receive(:on_change).once.with([path], :recursive => true)
          else
            listener.should_receive(:on_change).once.with([path], {})
          end

          touch 'unnecessary.txt'

          watch(listener, path) do
            rm 'unnecessary.txt'
          end
        end
      end

      context 'given an existing directory' do
        it 'detects the file removal' do
          fixtures do |path|
            if options[:recursive]
              listener.should_receive(:on_change).once.with([path], :recursive => true)
            else
              listener.should_receive(:on_change).once.with(["#{path}/a_directory"], {})
            end

            mkdir 'a_directory'
            touch 'a_directory/do_not_use.rb'

            watch(listener, path) do
              rm 'a_directory/do_not_use.rb'
            end
          end
        end
      end
    end
  end

  context 'multiple file operations' do
    it 'detects the added files' do
      fixtures do |path|
        if options[:recursive]
          listener.should_receive(:on_change).once.with([path], :recursive => true)
        else
          listener.should_receive(:on_change).once.with do |array, options|
            array.should =~ [path, "#{path}/a_directory"]
          end
        end

        watch(listener, path) do
          touch 'a_file.rb'
          touch 'b_file.rb'
          mkdir 'a_directory'
          # Needed for INotify, because of :recursive rb-inotify custom flag?
          sleep 0.05 if @adapter.is_a?(Listen::Adapters::Linux)
          touch 'a_directory/a_file.rb'
          touch 'a_directory/b_file.rb'
        end
      end
    end

    it 'detects the modified files' do
      fixtures do |path|
        if options[:recursive]
          listener.should_receive(:on_change).once.with([path], :recursive => true)
        else
          listener.should_receive(:on_change).once.with do |array, options|
            array.should =~ [path, "#{path}/a_directory"]
          end
        end

        touch 'a_file.rb'
        touch 'b_file.rb'
        mkdir 'a_directory'
        touch 'a_directory/a_file.rb'
        touch 'a_directory/b_file.rb'

        watch(listener, path) do
          touch 'b_file.rb'
          touch 'a_directory/a_file.rb'
        end
      end
    end

    it 'detects the removed files' do
      fixtures do |path|
        if options[:recursive]
          listener.should_receive(:on_change).once.with([path], :recursive => true)
        else
          listener.should_receive(:on_change).once.with do |array, options|
            array.should =~ [path, "#{path}/a_directory"]
          end
        end

        touch 'a_file.rb'
        touch 'b_file.rb'
        mkdir 'a_directory'
        touch 'a_directory/a_file.rb'
        touch 'a_directory/b_file.rb'

        watch(listener, path) do
          rm 'b_file.rb'
          rm 'a_directory/a_file.rb'
        end
      end
    end
  end

  context 'single directory operations' do
    it 'detects a moved directory' do
      fixtures do |path|
        if options[:recursive]
          listener.should_receive(:on_change).once.with([path], :recursive => true)
        else
          listener.should_receive(:on_change).once.with([path], {})
        end

        mkdir 'a_directory'
        touch 'a_directory/a_file.rb'
        touch 'a_directory/b_file.rb'

        watch(listener, path) do
          mv 'a_directory', 'renamed'
        end
      end
    end

    it 'detects a removed directory' do
      fixtures do |path|
        if options[:recursive]
          listener.should_receive(:on_change).once.with([path], :recursive => true)
        else
          listener.should_receive(:on_change).once.with do |array, options|
            array.should =~ [path, "#{path}/a_directory"]
          end
        end

        mkdir 'a_directory'
        touch 'a_directory/a_file.rb'
        touch 'a_directory/b_file.rb'

        watch(listener, path) do
          rm_rf 'a_directory'
        end
      end
    end
  end

  context "paused adapter" do
    context 'when a file is created' do
      it "doesn't detects the added file" do
        fixtures do |path|
          watch(listener, path) do
            @adapter.paused = true
            touch 'new_file.rb'
          end
          @called.should be_nil
        end
      end
    end
  end
end
