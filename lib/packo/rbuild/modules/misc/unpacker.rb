#--
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# packo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with packo. If not, see <http://www.gnu.org/licenses/>.
#++

module Packo; module RBuild; module Modules; module Misc

class Unpacker < Module
  @@formats = {}

  def self.register (type, &block)
    @@formats[type] = block
  end

  def self.do (path, to=nil)
    block = @@formats.find {|regexp, block|
      path.match(regexp)
    }.last rescue nil
    
    if block
      FileUtils.mkpath(to) rescue nil
      block.call(path, to)
    else
      raise ArgumentError.new('Archive format unsupported')
    end
  end

  def initialize (package)
    super(package)

    package.stages.add :unpack, self.method(:unpack), :after => :fetch, :strict => true

    before :initialize do |package|
      package.define_singleton_method :unpack, &Unpacker.method(:do)
    end
  end

  def unpack
    package.stages.callbacks(:unpack).do {
      Unpacker.do package.distfiles.first, "#{package.directory}/work"

      Dir.chdir "#{package.workdir}/#{package.name}-#{package.version}" rescue false
    }
  end
end

end; end; end; end