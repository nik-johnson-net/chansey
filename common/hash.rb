class Hash
    def keys_to_sym
        new_hash = {}
        each do |k,v|
            new_hash[k.to_sym] = v
        end
        new_hash
    end
end
