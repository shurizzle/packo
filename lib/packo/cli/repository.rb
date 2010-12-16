# encoding: utf-8
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

require 'open-uri'
require 'nokogiri'

require 'packo/cli/common'
require 'packo/cli/repository/helpers'

module Packo; module CLI

class Base < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'add URI...', 'Add repositories'
  map '-a' => :add
  def add (*uris)
    uris.each {|uri|
      uri  = URI.parse(uri)
      kind = nil
      type = nil
      name = nil

      if uri.scheme.nil? || uri.scheme == 'file'
        kind = :file

        if File.directory? uri.path
          dom = Nokogiri::XML.parse(File.read("#{uri.path}/repository.xml"))
        else
          dom = Nokogiri::XML.parse(File.read(uri.path))
        end

        uri = File.realpath(uri.path)

        type = dom.root['type'].to_sym
        name = dom.root['name']
      elsif ['http', 'https', 'ftp'].member?(uri.scheme)
        kind = :fetched

        xml = open(uri).read
        dom = Nokogiri::XML.parse(xml)

        type = dom.root['type'].to_sym
        name = dom.root['name']
      elsif @@scm.member?(uri.scheme)
        kind = :scm

        FileUtils.rm_rf("#{System.env[:TMP]}/.__repo", :secure => true)

        _checkout(uri, "#{System.env[:TMP]}/.__repo")

        dom = Nokogiri::XML.parse(File.read("#{System.env[:TMP]}/.__repo/repository.xml"))

        type = dom.root['type'].to_sym
        name = dom.root['name']
      end

      if !kind
        fatal "I don't know what to do with #{uri}"
        next
      end

      path = "#{System.env[:REPOSITORIES]}/#{type}/#{name}"

      if Repository.first(:type => type, :name => name)
        fatal "#{type}/#{name} already exists, delete it first"
        exit 10
      end

      case type
        when :binary
          path << '.xml'

          FileUtils.mkpath(File.dirname(path))
          File.write(path, open(kind == :file && !uri.to_s.match(/\.xml$/) ? "#{uri}/repository.xml" : uri).read)

        when :source
          FileUtils.rm_rf path, :secure => true rescue nil
          FileUtils.mkpath path rescue nil

          case kind
            when :fetched
              _checkout(dom.xpath('//address').first.text, path)

            when :scm
              FileUtils.cp_r "#{System.env[:TMP]}/.__repo/.", path, :preserve => true

            else
              _checkout(uri.to_s, path)
          end
      end

      begin
        add type, name, uri, path
        Packo.info "Added #{type}/#{name}"
      rescue Exception => e
        fatal 'Failed to add the cache'
        Packo.debug e

        if (repository = Repository.first(:type => type, :name => name))
          repository.destroy
        end
      end
    }
  end


  desc 'delete REPOSITORY...', 'Delete installed repositories'
  map '-d' => :delete, '-R' => :delete
  def delete (*names)
    names.each {|name|
      repository = Package::Repository.parse(name)

      if repository.type && !Package::Repository::Types.member?(repository.type)
        fatal "#{repository.type} is not a valid repository type"
        exit 20
      end

      conditions        = Hash[:name => repository.name]
      conditions[:type] = repository.type if repository.type

      repositories = Models::Repository.all(conditions)

      if repositories.empty?
        Packo.fatal "#{repository.type}/#{repository.name} doesn't exist"
        exit 21
      end

      Packo.info "Deleting #{[repository.type, repository.name].join('/')}"

      begin
        repositories.each {|repository|
          FileUtils.rm_rf repository.path, :secure => true

          repository.destroy
        }
      rescue Exception => e
        Packo.fatal "Something went wrong while deleting #{name}"

        Packo.debug e
      end
    }
  end

  desc 'update', 'Update installed repositories'
  def update
    Models.Repository.all.each {|repository|
      updated = false

      type = repository.type
      name = repository.name
      uri  = repository.uri.to_s
      path = repository.path

      case repository.type
        when :binary
          if (content = open(uri).read) != File.read(path)
            repository.destroy
            File.write(path, content)
            _add(:binary, name, uri, path)

            updated = true
          end

        when :source
          if _update(path)
            repository.destroy
            _add(:source, name, uri, path)

            updated = true
          end

        when :virtual
      end

      if updated
        Packo.info "Updated #{type}/#{name}"
      else
        Packo.info "#{type}/#{name} already up to date"
      end
    }
  end

  desc 'Searches packages with the given expression'
  opt 'exact', 'Search for the exact name', :type => :boolean, :default => false, :short_name => 'e'
  opt 'full', 'Include the repository that owns the package', :type => :boolean, :default => false
  opt 'type', 'The repository type', :type => :string, :in => ['source', 'binary', 'all'], :default => 'all', :short_name => 't'
  opt 'repository', 'Set a specific repository', :type => :string, :short_name => 'r'
  def search (expression='')
    _search(expression, params['exact'], params['repository'], params['type']).group_by {|package|
      "#{package.tags}/#{package.name}"
    }.sort.each {|(name, packages)|
      if params['full']
        packages.group_by {|package|
          "#{package.repository.type}/#{package.repository.name}"
        }.each {|name, packages|
          print "#{packages.first.tags}/#{packages.first.name.bold}"

          print ' ('
          print packages.map {|package|
            "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
          }.join(', ')
          print ')'

          print " <#{"#{package.repository.type}/#{package.repository.name}".black.bold} | #{package.repository.uri} | #{package.repository.path}>"
        }
      else
        print "#{packages.first.tags}/#{packages.first.name.bold} ("

        print packages.map {|package|
          "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
        }.join(', ')

        print ")"
      end
      
      print "\n"
    }
  end

  desc 'Searches packages with the given expression and returns detailed informations about them'
  opt 'exact', 'Search for the exact name', :type => :boolean, :default => false, :short_name => 'e'
  opt 'type', 'The repository type', :type => :string, :in => ['source', 'binary', 'all'], :default => 'all', :short_name => 't'
  opt 'repository', 'Set a specific repository', :type => :string, :short_name => 'r'
  def info (expression='')
    _search(expression, params['exact'], params['repository'], params['type']).group_by {|package|
      package.name
    }.sort.each {|(name, packages)|
      packages.sort {|a, b|
        a.version <=> b.version
      }.each {|package|
        print "[#{"source/#{package.repository.name}".black.bold}] "
        print package.name.bold
        print "-#{package.version.to_s.red}"
        print " (#{package.slot.blue.bold})" if package.slot
        print " [#{package.tags.join(' ').magenta}]"
        print "\n"

        puts "    #{'Description'.green}: #{package.description}"
        puts "    #{'Homepage'.green}:    #{package.homepage}"
        puts "    #{'License'.green}:     #{package.license}"
        puts "    #{'Maintainer'.green}:  #{package.model.maintainer || 'nobody'}"

        case package.repository.type
          when :binary
            puts "    #{'Features'.green}:    #{package.features.to_a.select {|f| f.enabled?}.map {|f| f.name}.join(' ')}"

            print "    #{'Builds'.green}:      "
            package.model.data.builds.each {|build|
              print 'With '

              if !build.features.empty?
                print build.features.bold
              else
                print 'nothing'
              end

              print " in #{build.flavor.bold} flavor" if build.flavor
              print " (SHA1 #{build.digest})".black.bold if build.digest
              print "\n                 "
            }

          when :source
            (print "\n"; next) unless package.model.data.features.length > 0

            print "    #{'Features'.green}:    "

            features = package.model.data.features
            length   = features.map {|feature| feature.name.length}.max

            features.each {|feature|
              if feature.enabled
                print "#{feature.name.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
              else
                print feature.name.black.bold
              end

              print "#{' ' * (4 + length - feature.name.length + (System.env[:NO_COLORS] && !feature.enabled ? 1 : 0))}#{feature.description || '...'}"

              print "\n                 "
            }
        end

        print "\n"
      }
    }
  end

  desc 'Shows installed repositories'
  def show (type='all')
    if Package::Repository::Types.member?(type.to_sym)
      _info "Installed #{type} repositories:"

      repositories = Repository.all(:type => type)
      length       = repositories.map {|repository| "#{repository.type}/#{repository.name}".length}.max

      repositories.each {|repository|
        puts "  #{repository.type}/#{repository.name}#{' ' * (4 + length - "#{repository.type}/#{repository.name}".length)}#{repository.uri} (#{repository.path})"
      }

      puts ''
    elsif type == 'all'
      Package::Repository::Types.each {|type|
        show(type)
      }
    end
  end

  desc 'Outputs the path of a given repository'
  def path (name)
    repository = Repository.first(Package::Repository.parse(name).to_hash)

    exit if !repository

    puts repository.path
  end

  desc 'Outputs the URI of a given package'
  def uri (name)
    repository = Repository.first(Package::Repository.parse(name).to_hash)

    exit if !repository

    puts repository.URI
  end

  desc 'Rehash the repository caches'
  def rehash (*names)
    repositories = []

    if names.empty?
      repositories << Repository.all
    else
      names.each {|name|
        repositories << Repository.all(:name => name)
      }
    end

    repositories.flatten.compact.each {|repository|
      type = repository.type
      name = repository.name
      uri  = repository.uri
      path = repository.path

      _info "Rehashing #{type}/#{name}"

      repository.destroy

      case type
        when :binary
          _add(:binary, name, uri, path)

        when :source
          _add(:source, name, uri, path)
      end
    }
  end



  private

  def _add (type, name, uri, path)
    Repository.wrap(Models::Repository.new(
      :type => type,
      :name => name,

      :uri  => uri,
      :path => path
    )).populate
  end

  def _delete (name, type)
    Models::Repository.first(:name => name, :type => type).destroy
  end

  def _checkout (uri, path)
    uri = URI.parse(uri.to_s) if !uri.is_a?(URI)

    if !uri.scheme
      if File.directory?("#{uri}/.git")
        scm = 'git'
      end
    else
      scm = uri.scheme
    end

    if !@@scm.member?(scm)
      fatal "#{scm} is an unsupported SCM"
      exit 40
    end

    case scm
      when 'git'; Packo.sh 'git', 'clone', uri.to_s, path, :silent => !System.env[:VERBOSE]
    end
  end

  def _update (path)
    result = false

    old = Dir.pwd; Dir.chdir(path)

    if !result && (`git reset --hard`) && (`git pull`.strip != 'Already up-to-date.' rescue nil)
      result = true
    end

    Dir.chdir(old)

    return result
  end
end

end; end