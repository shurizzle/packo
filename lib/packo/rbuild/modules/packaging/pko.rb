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

module Packo; module RBuild; module Modules; module Packaging

Packager.register('.pko') {
  pack do |package, to=nil|
    path = to || "#{package.to_s(:package)}.pko"

    Dir.chdir package.directory

    package.filesystem.pre.save("#{package.directory}/pre", 0755)
    package.filesystem.post.save("#{package.directory}/post", 0755)
    package.filesystem.selectors.save("#{package.directory}/selectors", 0755)

    manifest.new(package).save('manifest.yml')

    package.callbacks(:packing).do {
      Do.clean(package.distdir)

      Packo.sh 'tar', 'cJf', path, *['dist/', 'pre/', 'post/', 'selectors/', 'manifest.yml'], '--preserve', silent: true
    }

    path
  end

  unpack do |package, to=nil|
    FileUtils.mkpath(to) rescue nil

    Packo.sh 'tar', 'xJf', pacakage, '-C', to || "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(package)}", '--preserve', :silent => true
  end

  manifest do
    require 'base64'

    def self.parse (text)
      data = YAML.parse(text).transform

      self.new(OpenStruct.new(
        maintainer: data['package']['maintainer'],

        tags:     Packo::Package::Tags.parse(data['package']['tags']),
        name:     data['package']['name'],
        version:  Versionub.parse(data['package']['version']),
        slot:     data['package']['slot'],
        revision: data['package']['revision'],

        exports: Marshal.load(Base64.decode64(data['package']['exports'])),

        description: data['package']['description'],
        homepage:    data['package']['homepage'].split(/\s+/),
        license:     data['package']['license'].split(/\s+/),

        flavor:   Packo::Package::Flavor.parse(data['package']['flavor'] || ''),
        features: Packo::Package::Features.parse(data['package']['features'] || ''),

        environment: data['package']['environment'],

        dependencies: Package::Dependencies.new(data['dependencies'].map {|dependency|
          Package::Dependency.parse(dependency)
        }),

        selector: data['selectors']
      ))
    end

    def self.open (path)
      self.parse(File.read(path))
    end

    attr_reader :package, :dependencies, :selectors

    def initialize (package)
      @package = package 

      @dependencies = what.dependencies
      @selectors    = [what.selector].flatten

      if (what.filesystem.selectors rescue false)
        what.filesystem.selectors.each {|name, file|
          matches = file.content.match(/^#\s*(.*?):\s*(.*)([\n\s]*)?\z/) or next

          @selectors << OpenStruct.new(name: matches[1], description: matches[2], path: name)
        }
      end
    end

    def to_yaml
      data = {
        'package'      => {},
        'dependencies' => [],
        'selectors'    => []
      }

      data['package'].merge!(Hash[package.to_hash.map {|name, value|
        next if value.nil?

        [name.to_s, value.to_s]
      }.compact])

      data['package']['environment'] = package.environment.reject {|name, value|
        [:DATABASE, :FLAVORS, :PROFILES, :CONFIG_PATH, :MAIN_PATH, :INSTALL_PATH, :FETCHER,
         :NO_COLORS, :DEBUG, :VERBOSE, :TMP, :SECURE
        ].member?(name.to_sym)
      }.map {|name, value|
        next if value.nil?

        [name.to_s, value.to_s]
      }.compact

      data['package']['exports'] = Base64.encode64(Marshal.dump(package.exports))

      dependencies.each {|dependency|
        data['dependencies'] << dependency.to_s
      }

      selectors.each {|selector|
        data['selectors'] << selector.to_hash
      }

      data.to_yaml
    end

    def save (to, options={})
      File.write(to, self.to_s)
    end

    def to_s (options={})
      to_yaml
    end
  end
}

end; end; end; end
