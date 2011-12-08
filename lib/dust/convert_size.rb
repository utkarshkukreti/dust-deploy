module Dust

  # converts string to kilobytes (rounded)
  def self.convert_size s
    i, unit = s.split(' ')

    case unit.downcase
    when 'kb'
      return i.to_i
    when 'mb'
      return (i.to_f * 1024).to_i
    when 'gb'
      return (i.to_f * 1024 * 1024).to_i
    when 'tb'
      return (i.to_f * 1024 * 1024 * 1024).to_i
    else
      return false
    end
  end

end
