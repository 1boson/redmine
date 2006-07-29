# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class CustomValue < ActiveRecord::Base
  belongs_to :custom_field
  belongs_to :customized, :polymorphic => true

protected
  def validate
    # errors are added to customized object unless it's nil
    object = customized || self
    
    object.errors.add(custom_field.name, :activerecord_error_blank) if custom_field.is_required? and value.empty?
    object.errors.add(custom_field.name, :activerecord_error_invalid) unless custom_field.regexp.empty? or value =~ Regexp.new(custom_field.regexp)

    object.errors.add(custom_field.name, :activerecord_error_too_short) if custom_field.min_length > 0 and value.length < custom_field.min_length and value.length > 0
    object.errors.add(custom_field.name, :activerecord_error_too_long) if custom_field.max_length > 0 and value.length > custom_field.max_length

    case custom_field.field_format
    when "int"
      object.errors.add(custom_field.name, :activerecord_error_not_a_number) unless value =~ /^[0-9]*$/	
    when "date"
      object.errors.add(custom_field.name, :activerecord_error_invalid) unless value =~ /^(\d+)\/(\d+)\/(\d+)$/ or value.empty?
    when "list"
      object.errors.add(custom_field.name, :activerecord_error_inclusion) unless custom_field.possible_values.split('|').include? value or value.empty?
    end
  end
end

