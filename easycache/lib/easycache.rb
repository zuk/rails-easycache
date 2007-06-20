# Easycache
class Easycache
  @@cache = ActionController::Base.fragment_cache_store
  
  class << Easycache
    def write(keyname, value, options = nil)
      @@cache.write(namespace_keyname(keyname), value.to_yaml, options)
      value
    end
    
    def read(keyname, options = nil)
      value = @@cache.read(namespace_keyname(keyname))
      return value unless value.kind_of? String
      YAML.load(value)
    end
    
    def cache(keyname, options=nil, &block)
      read(keyname, options) ||
        write(keyname, yield, options)
    end
    
    def delete(keyname, options = nil)
      @@cache.delete(namespace_keyname(keyname), options)
    end
    
    private
    def namespace_keyname(keyname)
      "EASYCACHE::#{keyname}"
    end
  end
end