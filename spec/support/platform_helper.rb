def darwin?
  RbConfig::CONFIG['target_os'] =~ /darwin/i
end

def linux?
  RbConfig::CONFIG['target_os'] =~ /linux/i
end

def bsd?
  RbConfig::CONFIG['target_os'] =~ /bsd|dragonfly/i
end

def windows?
  RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
end
