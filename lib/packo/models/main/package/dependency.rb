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

module Packo; module Models; module Main; class Package

class Dependency
  include DataMapper::Resource

  belongs_to :package

  property :categories, String, :length => 255, :key => true
  property :name,       String,                 :key => true
  property :version,    String,                 :key => true
  property :slot,       String,  :default => ''
  property :revision,   Integer, :default => 0

  property :flavors,  Text, :default => ''
  property :features, Text, :default => ''
end

end; end; end; end
