#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

module Packo; module RBuild; module Modules; module Fetching

class Bazaar < Module
  def self.do (*args)
    Packo.sh 'bzr', *args
  end

  def self.fetch (location, path)
    Do.rm path

    if location.repository && location.branch
      Bazaar.do :checkout, '--lightweight', "#{location.repository}/#{location.branch}", path
    else
      Bazaar.do :checkout, '--lightweight', location.repository || location.branch, path
    end
  end

  def initialize (package)
    super(package)

    package.avoid [Fetcher, Unpacker]

    package.stages.add :fetch, self.method(:fetch), after: :beginning

    package.after :initialize do
      package.dependencies << 'vcs/bzr!'
    end
  end

  def finalize
    package.stages.delete :fetch, self.method(:fetch)
  end

  def fetch
    package.stages.callbacks(:fetch).do {
      package.clean!
      package.create!

      package.source.to_hash.each {|name, value|
        package.source[name] = value.to_s.interpolate(package)
      }

      Bazaar.fetch package.source, package.workdir

      Do.cd package.workdir
    }
  end
end

end; end; end; end
