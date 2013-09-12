# Generates a small time difference before performing a time sensitive
# task (like comparing mtimes of files).
#
# @note Modification time for files only includes the milliseconds on Linux with MRI > 1.9.2
#   and platform that support it (OS X 10.8 not included),
#   that's why we generate a difference that's greater than 1 second.
#
def sleep_until_next_second
  return unless darwin?

  t = Time.now
  diff = t.to_f - t.to_i

  sleep(1.05 - diff)
end

def high_file_time_precision_supported?
  @high_file_time_precision ||=File.mtime(__FILE__).to_f.to_s[-2..-1] != '.0'
rescue
  false
end
