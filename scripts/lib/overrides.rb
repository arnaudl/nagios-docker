class Hash
  def deep_merge(other_hash)
    merge(other_hash) do |_, this_val, other_val|
      if this_val.is_a?(Hash) && other_val.is_a?(Hash)
        this_val.deep_merge(other_val)
      else
        other_val
      end
    end
  end

  def deep_clone
    Marshal.load(Marshal.dump(self))
  end
end
