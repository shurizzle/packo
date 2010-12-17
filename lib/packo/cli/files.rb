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

require 'packo/system'
require 'packo/models'
require 'packo/cli'

module Packo; module CLI

class Files < Thor
  include Thor::Actions

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'package PACKAGE', 'Get a file list of a given package'
  def package (name)
    if name.end_with?('.pko')
      path = "#{System.env[:TMP]}/.__packo_unpacked/#{File.basename(name)}"
      RBuild::Modules::Packaging::PKO.unpack(File.realpath(name), path)

      length = "#{path}/dist".length

      Find.find("#{path}/dist") {|file|
        type = nil
        path = "/#{file[length, file.length]}".gsub(%r{/*/}, '/').sub(%r{/$}, '')
        meta = nil

        if File.directory? file
          type = :dir
        elsif File.symlink? file
          type = :sym
          meta = File.readlink file
        elsif File.file? file
          type = :obj
        end

        case type
          when :dir; puts "--- #{path if path != '/'}/"
          when :sym; puts ">>> #{path} -> #{meta}".cyan.bold
          when :obj; puts ">>> #{path}".bold
        end
      }
    else
      package = CLI.search_installed(name).first

      if !package
        fatal "No package matches #{name}"
        exit! 10
      end

      package.model.contents.each {|content|
        case content.type
          when :dir; puts "--- /#{content.path}#{'/' if !content.path.empty?}"
          when :sym; puts ">>> /#{content.path} -> #{content.meta}".cyan.bold
          when :obj; puts ">>> /#{content.path}".bold
        end
      }
    end
  end

  desc 'check [PACKAGE...]', 'Check contents for the given packages'
  def check (*names)
    packages = []

    if names.empty?
      packages << Models::InstalledPackage.all.map {|pkg|
        Package.wrap(pkg)
      }
    else
      names.each {|name|
        packages << Models.search_installed(name)
      }
    end

    packages.flatten.compact.each {|package|
      print "[#{package.repository.black.bold}] " if package.repository
      print "#{package.tags}/"
      print package.name.bold
      print "-#{package.version.to_s.red}"
      print " (#{package.slot.to_s.blue.bold})" if package.slot
      print " [#{package.features}]" unless package.features.empty?
      print " {#{package.flavor}}"   unless package.flavor.empty?
      print "\n"

      package.model.contents.each {|content|
        path = "/#{content.path}"

        case content.type
          when :dir
            if !(File.directory?(path) rescue false)
              puts "#{'FAIL ' if System.env[:NO_COLORS]}--- #{path}#{'/' if path != '/'}".red
            else
              puts "#{'OK   ' if System.env[:NO_COLORS]}--- #{path}#{'/' if path != '/'}".green
            end

          when :sym
            if content.meta != (File.readlink(path) rescue nil)
              puts "#{'FAIL ' if System.env[:NO_COLORS]}>>> #{path} -> #{content.meta}".red
            else
              puts "#{'OK   ' if System.env[:NO_COLORS]}>>> #{path} -> #{content.meta}".green
            end
            
          when :obj
            if content.meta != (Digest::SHA1.hexdigest(File.read(path)) rescue nil)
              puts "#{'FAIL ' if System.env[:NO_COLORS]}>>> #{path}".red
            else
              puts "#{'OK   ' if System.env[:NO_COLORS]}>>> #{path}".green
            end
        end
      }

      puts ''
    }
  end

end

end; end