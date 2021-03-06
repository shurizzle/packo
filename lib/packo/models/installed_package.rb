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

require 'packo/models/tag'
require 'packo/models/installed_package/dependency'
require 'packo/models/installed_package/content'

module Packo; module Models

class InstalledPackage
  include DataMapper::Resource

  property :id, Serial

  property :repo, String
  has n,   :tags, through: Resource, constraint: :destroy

  property :tags_hashed, String,  length: 40,   required: true, unique_index: :a
  property :name,        String,  length: 255,  required: true, unique_index: :a
  property :version,     Version,               required: true
  property :slot,        String,  default: '',                  unique_index: :a
  property :revision,    Integer, default: 0

  property :flavor,  Text
  property :features, Text

  property :description,  Text
  property :homepage,     Text
  property :license,      Text

  property :maintainer, String

  property :manual, Boolean,                       default: false
  property :type,   Enum[:both, :runtime, :build], default: :both

  property :destination, Text

  property :created_at, DateTime

  has n, :dependencies, constraint: :destroy
  has n, :contents,     constraint: :destroy

  def self.search (expression, options={})
    if expression.start_with?('(') && expression.end_with?(')')
      result = find_by_expression(expression[1, expression.length - 2])
    else
      whole, validity, package, expression = expression.match(/^([<>]?=?)?(.+?)\s*(?:\((.*)\))?$/).to_a

      package = Packo::Package.parse(package || '')

      conditions = { order: [:name.asc] }

      if options[:exact]
        conditions[:name] = package.name if package.name
      else
        conditions[:name.like] = "%#{package.name}%" if package.name
      end

      if !validity || validity.empty?
        conditions[:version] = package.version if package.version
        conditions[:slot]    = package.slot    if package.slot
      end

      result = all(conditions)

      if !package.tags.empty?
        result = result.to_a.select {|pkg|
          Packo::Package.wrap(pkg).tags == package.tags
        }
      end

      if validity && !validity.empty?
        result = result.select {|pkg|
          case validity
            when '~', '~=' then true
            when '>'       then pkg.version >  package.version
            when '>='      then pkg.version >= package.version
            when '<'       then pkg.version <  package.version
            when '<='      then pkg.version <= package.version
            else                pkg.version == package.version
          end
        }
      end

      if expression && !expression.empty?
        expression = Packo::Boolean::Expression.parse(expression)

        result.select! {|pkg|
          expression.evaluate(Packo::Package.wrap(pkg))
        }
      end
    end

    if options[:repository]
      result.select! {|pkg|
        pkg.repo == options[:repository]
      }
    end

    return result
  end

  def self.find_by_expression (expression)
    if DataMapper.repository.adapter.respond_to? :select
      joins, names, expression = _expression_to_sql(expression)

      (repository.adapter.select(%{
        SELECT DISTINCT packo_models_installed_packages.id

        FROM packo_models_installed_packages

        #{joins}

        WHERE #{expression}
      }, *names)).map {|id|
        InstalledPackage.get(id)
      }
    else
      expression = Packo::Boolean::Expression.parse(expression)

      all.select {|pkg|
        expression.evaluate(Packo::Package.wrap(pkg))
      }
    end
  end

private
  def self._expression_to_sql (value)
    value.downcase!
    value.gsub!(/(\s+and\s+|\s*&&\s*)/i, ' && ')
    value.gsub!(/(\s+or\s+|\s*\|\|\s*)/i, ' || ')
    value.gsub!(/(\s+not\s+|\s*!\s*)/i, ' !')
    value.gsub!(/\(\s*!/, '(!')

    joins      = String.new
    names      = []
    expression = value.clone

    expression.scan(/(("(([^\\"]|\\.)*)")|([^\s&!|()]+))/) {|match|
      names.push((match[2] || match[4]).downcase)
    }

    names.compact!
    names.uniq!

    names.each_index {|index|
      joins << %{
        LEFT JOIN (
            SELECT _used_tag_#{index}.installed_package_id AS package_id

            FROM packo_models_installed_package_tags AS _used_tag_#{index}

            INNER JOIN packo_models_tags AS _tag_#{index}
                ON _used_tag_#{index}.tag_id = _tag_#{index}.id AND _tag_#{index}.name = ?
        ) AS _tag_check_#{index}
            ON packo_models_installed_packages.id = _tag_check_#{index}.package_id
      }

      if (replace = names[index]).match(/[\s&!|]/)
        replace = %{"#{replace}"}
      end

      expression.gsub!(/([\s()]|\G)!\s*#{Regexp.escape(replace)}([\s()]|$)/, "\\1 (_tag_check_#{index}.package_id IS NULL) \\2")
      expression.gsub!(/([\s()]|\G)#{Regexp.escape(replace)}([\s()]|$)/,     "\\1 (_tag_check_#{index}.package_id IS NOT NULL) \\2")
    }

    expression.gsub!(/([\G\s()])&&([\s()\A])/,   '\1 AND \2')
    expression.gsub!(/([\G\s()])\|\|([\s()\A])/, '\1 OR  \2')
    expression.gsub!(/([\G\s()])!([\s()\A])/,    '\1 NOT \2')

    return joins, names, expression
  end
end

end; end
