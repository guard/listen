# frozen_string_literal: true

module Listen
  class Error < RuntimeError
    class NotStarted < Error; end
  end
end
