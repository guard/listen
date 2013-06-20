# Generates a small time difference before performing a time sensitive
# task (like comparing mtimes of files).
#
# @note Modification time for files only includes the milliseconds on Linux with MRI > 1.9.2
#   and platform that support it (OS X 10.8 not included),
#   that's why we generate a difference that's greater than 1 second.
#
def sleep_until_next_second
  t = Time.now
  diff = t.to_f - t.to_i

  sleep(1 - diff)
end
