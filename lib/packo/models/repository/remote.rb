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

module Packo; module Models; class Repository

class Remote
  class Piece
    include DataMapper::Resource
   
    belongs_to :remote

    property :id, Serial

    property :type, Text
    property :name, Text

    property :description, Text
    property :location,    Location
  end

  include DataMapper::Resource
  
  property :id, Serial

  property :name, String, required: true

  property :uri,  URI
  property :path, Text

  has n, :pieces
end

end; end; end