module Redmine
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 5
    TINY  = 0

    STRING= [MAJOR, MINOR, TINY].join('.')
    
    def self.to_s; STRING end    
  end
end
