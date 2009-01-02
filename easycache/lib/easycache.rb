# Easycache
class Easycache
  if Rails.respond_to?(:cache)
    # New caching mechanism for Rails 2.1+
    class << Easycache
      # Store value in the cache under keyname.
      #
      # The options hash can have an :expires_in value that will expire the given
      # entry once this many seconds have passed.
      #
      # Note that the value must be serializable via Marshal.dump(). This means 
      # that certain objects (for example, IO handles) can't be stored in the
      # cache. The :raw => true option will prevent the value from being
      # automatically serialized.
      #
      # Example:
      #
      #   data = {:bar => 'foo'}
      #   Easycache.write('test', data, {:expires_in => 15})
      #
      # For the expiry value you can use time conversion extensions like:
      #
      #   Easycache.write('test', data, {:expires_in => 24.hours})
      #
      def write(keyname, value, options = {})
        keyname = keyname.to_s
        options[:expires_in] ||= options[:expiry]
        Rails.cache.write(namespace_keyname(keyname), value, options)
        value
      end
      
      # Retrieve the cached value under keyname; or nil if no value is cached
      # under this keyname.
      def read(keyname)
        keyname = keyname.to_s
        Rails.cache.read(namespace_keyname(keyname))
      end
      
      # This convenience method allows you to cache the return value of any block
      # of code.
      #
      # Example:
      #
      #   person = Easycache.cache('foo') do
      #     Person.find_by_name("John")
      #   end
      #
      # The first time the above code is run, the block will be executed and its
      # result will be cache dand returned. From then on, instead of executing
      # the block, Easycache will return the previously cached value.
      #
      # Note that if your block returns nil, it will not be cached and the block
      # will continue to be executed.
      #
      # As with Easycache#write, you can specify an options hash with an :expires_in
      # value.
      #
      # Example:
      #
      #   person = Easycache.cache('foo', :expires_in => 24.hours) do
      #     Person.find_by_name("John")
      #   end
      def cache(keyname, options = {}, &block)
        keyname = keyname.to_s
        (Rails.cache.exist?(keyname) && read(keyname)) ||
          write(keyname, yield, options)
      end
      
      # Returns the value stored at the given keyname (if any) and deletes it from 
      # the cache.
      # Returns nil and does nothing if the keyname doesn't exist.
      def delete(keyname)
        keyname = keyname.to_s
        Rails.cache.delete(namespace_keyname(keyname))
      end
      
      private
        # We automatically prefix all keynames with a string to help prevent 
        # namespace clashes.
        def namespace_keyname(keyname)
          keyname = keyname.to_s
          "EASYCACHE::#{keyname}"
        end
    end
  else
    @@cache = ActionController::Base.fragment_cache_store
    
    # Old caching mechanism for Rails versions prior to 2.1
    class << Easycache
      # Store value in the cache under keyname.
      #
      # The options hash can have an :expires_in value that will expire the given
      # entry once this many seconds have passed.
      #
      # Note that the value must be serializable via to_yaml(). This means that
      # certain objects (for example, IO handles) can't be stored in the cache.
      #
      # Example:
      #
      #   data = {:bar => 'foo'}
      #   Easycache.write('test', data, {:expires_in => 15})
      #
      # For the expiry value you can use time conversion extensions like:
      #
      #   Easycache.write('test', data, {:expires_in => 24.hours})
      #
      def write(keyname, value, options = {})
        keyname = keyname.to_s
        raise "Easycache keyname cannot end with '::EXPIRY'" if keyname =~ /::EXPIRY$/
        @@cache.write(namespace_keyname(keyname), value.to_yaml, options)
        if (options[:expires_in] || options[:expiry])
          @@cache.write(namespace_keyname(keyname)+"::EXPIRY",
            Time.now.to_i + (options[:expires_in] || options[:expiry]))
        end
        value
      end
      
      # Retrieve the cached value under keyname; or nil if no value is cached
      # under this keyname.
      def read(keyname)
        keyname = keyname.to_s
        if expiry = @@cache.read(namespace_keyname(keyname)+"::EXPIRY")
          if expiry.to_i < Time.now.to_i
            self.delete(keyname)
            self.delete(keyname+"::EXPIRY")
            return nil
          end
        end
        value = @@cache.read(namespace_keyname(keyname))
        return value unless value.kind_of? String
        YAML.load(value)
      end
      
      # This convenience method allows you to cache the return value of any block
      # of code.
      #
      # Example:
      #
      #   person = Easycache.cache('foo') do
      #     Person.find_by_name("John")
      #   end
      #
      # The first time the above code is run, the block will be executed and its
      # result will be cache dand returned. From then on, instead of executing
      # the block, Easycache will return the previously cached value.
      #
      # Note that if your block returns nil, it will not be cached and the block
      # will continue to be executed.
      #
      # As with Easycache#write, you can specify an options hash with an :expires_in
      # value.
      #
      # Example:
      #
      #   person = Easycache.cache('foo', :expires_in => 24.hours) do
      #     Person.find_by_name("John")
      #   end
      def cache(keyname, options = {}, &block)
        keyname = keyname.to_s
        read(keyname) ||
          write(keyname, yield, options)
      end
      
      # Returns the value stored at the given keyname (if any) and deletes it from 
      # the cache.
      # Returns nil and does nothing if the keyname doesn't exist.
      def delete(keyname)
        keyname = keyname.to_s
        @@cache.delete(namespace_keyname(keyname), nil)
      end
      
      private
        # We automatically prefix all keynames with a string to help prevent 
        # namespace clashes.
        def namespace_keyname(keyname)
          keyname = keyname.to_s
          "EASYCACHE::#{keyname}"
        end
    end
  end
end
