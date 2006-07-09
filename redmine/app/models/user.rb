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

require "digest/sha1"

class User < ActiveRecord::Base
  has_many :memberships, :class_name => 'Member', :include => [ :project, :role ], :dependent => true
	
  attr_accessor :password, :password_confirmation
  attr_accessor :last_before_login_on
  # Prevents unauthorized assignments
  attr_protected :login, :admin, :password, :password_confirmation, :hashed_password
	
  validates_presence_of :login, :firstname, :lastname, :mail
  validates_uniqueness_of :login, :mail	
  # Login must contain lettres, numbers, underscores only
  validates_format_of :login, :with => /^[a-z0-9_]+$/i
  validates_format_of :mail, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  # Password length between 4 and 12
  validates_length_of :password, :in => 4..12, :allow_nil => true
  validates_confirmation_of :password, :allow_nil => true

  def before_save
    # update hashed_password if password was set
    self.hashed_password = User.hash_password(self.password) if self.password
  end
	
  # Returns the user that matches provided login and password, or nil
  def self.try_to_login(login, password)
    user = find(:first, :conditions => ["login=? and hashed_password=? and locked=?", login, User.hash_password(password), false])
    if user
      user.last_before_login_on = user.last_login_on
      user.update_attribute(:last_login_on, Time.now)
    end
    user
  end
	
  # Return user's full name for display
  def display_name
    firstname + " " + lastname
  end

  def check_password?(clear_password)
    User.hash_password(clear_password) == self.hashed_password
  end

  
  def role_for_project(project_id)
    @role_for_projects ||=
      begin
        roles = {}
        self.memberships.each { |m| roles.store m.project_id, m.role_id }
        roles
      end
    @role_for_projects[project_id]
  end
	
private
  # Return password digest
  def self.hash_password(clear_password)
    Digest::SHA1.hexdigest(clear_password || "")
  end
end
