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

require 'packo/system'
require 'packo/extensions'

if Packo::System.host.kernel == 'windows'
  require 'win32ole'
end

module Packo; module OS

class Process
  include StructLike

  if Packo::System.host.kernel == 'linux' || Packo::System.host.kernel == 'windows'
    def self.all
      Dir['/proc/[0-9]*'].map {|ps|
        next unless (pid = ps[6 .. -1]).numeric?

        Process.new(pid.to_i,
          name:    File.read(File.join(ps, 'comm')).strip,
          command: File.read(File.join(ps, 'cmdline')).strip
        ) rescue nil
      }.compact
    end

    def self.from_id (id)
      return unless id.numeric? && File.directory?("/proc/#{id}")

      Process.new(id,
        name:    File.read("/proc/#{id}/comm").strip,
        command: File.read("/proc/#{id}/cmdline").strip
      )
    end
  else
    fail 'Unsupported platform, contact the developers please.'
  end

  def self.kill (what, signal=:INT)
    if what.is_a?(String) || what.is_a?(Regexp)
      OS::Process.all.map {|p|
        p.kill(signal) if p.command.match(what)
      }.compact.all?
    else
      OS::Process.from_id(what).kill(signal)
    end
  end

  attr_reader :id

  def initialize (id, data={})
    @id   = id
    @data = data
  end

  def kill (force=false)
    result = if force
      ::Process.kill(:KILL, @id)
    else
      ::Process.kill(:INT, @id)
    end rescue 1 == 1

    if result
      ::Process.wait(@id) rescue nil
    end

    result
  end

  def send (signal)
    ::Process.kill(signal)
  end
end

end; end