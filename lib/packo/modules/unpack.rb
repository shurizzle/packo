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

require 'packo/module'

module Packo

module Modules

class Unpack < Module
  def initialize (package)
    super(package)

    Packo.env('WORKDIR', '/tmp') if !Packo.env('WORKDIR')

    package.stages.add :unpack, self.method(:unpack), :after => :fetched, :strict => true
  end

  def unpack
    package.distfiles.each {|file|
      `tar xf "#{file}" -C #{Packo.env('WORKDIR')}`
    }
  end
end

end

end
