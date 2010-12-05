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

module Packo; module RBuild; module Modules; module Packaging

class PKO < Module
  def self.pack (name, *files)
    Packo.sh 'tar', 'cJf', name, *files, '--preserve', :silent => true
  end

  def self.unpack (name, to)
    FileUtils.mkpath(to) rescue nil

    Packo.sh 'tar', 'xJf', name, '-C', to, '--preserve', :silent => true
  end

  def initialize (package)
    super(package)

    package.stages.add :pack, self.method(:pack), :after => :install
  end

  def pack
    package.stages.callbacks(:pack).do {
      path = "#{package.to_s(:package)}.pko"

      Dir.chdir package.directory

      FileUtils.mkpath "#{package.directory}/pre"

      package.filesystem.pre.each {|name, file|
        File.write("pre/#{name}", file.content, 0777)
      }

      FileUtils.mkpath "#{package.directory}/post"
      package.filesystem.post.each {|name, file|
        File.write("post/#{name}", file.content, 0777)
      }

      FileUtils.mkpath "#{package.directory}/selectors"
      package.filesystem.selectors.each {|name, file|
        File.write("selectors/#{name}", file.content, 0777)
      }

      Package::Manifest.new(package).save('manifest.xml')

      PKO.pack(path, 'dist/', 'pre/', 'post/', 'selectors/', 'manifest.xml')

      path
    }
  end
end

end; end; end; end
