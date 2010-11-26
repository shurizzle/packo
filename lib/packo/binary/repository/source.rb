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

require 'packo/models'
require 'packo/rbuild'
require 'packo/binary/helpers'

module Packo; module Binary; class Repository

class Source < Repository
  include Packo::Binary::Helpers
  include Packo::Models

  def initialize (repository)
    super(repository)
  end

  def populate (what=[self.path], root=self.path)
    last = nil

    what.select {|what| File.directory? what}.each {|what|
      if File.file? "#{what}/#{File.basename(what)}.rbuild"
        Dir.glob("#{what}/#{File.basename(what)}-*.rbuild").each {|version|
          info "Parsing #{version.sub("#{self.path}/", '')}" if Environment[:VERBOSE]

          pkg = Packo::Package.new(
            :name    => File.basename(what),
            :version => version.match(/-(\d.*?)\.rbuild$/)[1]
          )

          begin
            loadPackage(what, pkg)
          rescue LoadError => e
            warn e.to_s if Environment[:VERBOSE]
          end

          package = RBuild::Packages[:last]

          if package.name != pkg.name || package.version != pkg.version
            warn "Package not found: #{pkg.name}" if Environment[:VERBOSE]
            next
          end

          pkg = repository.packages.first_or_create(
            :repo => repository,

            :tags_hashed => package.tags.hash,
            :name        => package.name,
            :version     => package.version,
            :slot        => package.slot,
            :revision    => package.revision
          )

          pkg.update(
            :description => package.description,
            :homepage    => [package.homepage].flatten.join(' '),
            :license     => [package.license].flatten.join(' ')
          )

          package.tags.each {|tag|
            pkg.tags.first_or_create(:name => tag.to_s)
          }

          package.features.each {|feature|
            feature = pkg.data.features.first_or_create(
              :source => pkg.data,
              :name   => feature.name
            )

            feature.update(
              :description => feature.description,
              :enabled     => feature.enabled?
            )
          }

          pkg.save

          RBuild::Packages.delete package.to_s(:name)
          RBuild::Packages.delete package.to_s
        }
      else
        populate(Dir.entries(what).map {|e|
          "#{what}/#{e}" if e != '.' && e != '..'
        }.compact, root)
      end
    }
  end
end

end; end; end
