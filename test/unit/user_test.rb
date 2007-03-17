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

require File.dirname(__FILE__) + '/../test_helper'

class UserTest < Test::Unit::TestCase
  fixtures :users

  def setup
    @admin = User.find(1)
    @jsmith = User.find(2)
  end
  
  def test_truth
    assert_kind_of User, @jsmith
  end

  def test_create
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    
    user.login = "jsmith"
    user.password, user.password_confirmation = "password", "password"
    # login uniqueness
    assert !user.save
    assert_equal 1, user.errors.count
  
    user.login = "newuser"
    user.password, user.password_confirmation = "passwd", "password"
    # password confirmation
    assert !user.save
    assert_equal 1, user.errors.count

    user.password, user.password_confirmation = "password", "password"
    assert user.save
  end

  def test_update
    assert_equal "admin", @admin.login
    @admin.login = "john"
    assert @admin.save, @admin.errors.full_messages.join("; ")
    @admin.reload
    assert_equal "john", @admin.login
  end
  
  def test_validate
    @admin.login = ""
    assert !@admin.save
    assert_equal 2, @admin.errors.count
  end
  
  def test_password
    user = User.try_to_login("admin", "admin")
    assert_kind_of User, user
    assert_equal "admin", user.login
    user.password = "hello"
    assert user.save
    
    user = User.try_to_login("admin", "hello")
    assert_kind_of User, user
    assert_equal "admin", user.login
    assert_equal User.hash_password("hello"), user.hashed_password    
  end
  
  def test_lock
    user = User.try_to_login("jsmith", "jsmith")
    assert_equal @jsmith, user
    
    @jsmith.status = User::STATUS_LOCKED
    assert @jsmith.save
    
    user = User.try_to_login("jsmith", "jsmith")
    assert_equal nil, user  
  end
  
  def test_rss_key
    assert_nil @jsmith.rss_key
    key = @jsmith.get_or_create_rss_key
    assert_kind_of Token, key
    assert_equal 40, key.value.length
    
    @jsmith.reload
    assert_equal key.value, @jsmith.get_or_create_rss_key.value
    
    @jsmith.reload
    assert_equal key.value, @jsmith.rss_key.value
  end
end
