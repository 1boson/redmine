# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

class SettingsController < ApplicationController
  layout 'base'	
  before_filter :require_admin
  
  def index
    edit
    render :action => 'edit'
  end

  def edit
    if request.post? and params[:settings] and params[:settings].is_a? Hash
      params[:settings].each { |name, value| Setting[name] = value }
      redirect_to :action => 'edit' and return
    end
  end
  
  def plugin
    plugin_id = params[:id].to_sym
    @plugin = Redmine::Plugin.registered_plugins[plugin_id]
    if request.post?
      Setting["plugin_#{plugin_id}"] = params[:settings]
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'plugin', :id => params[:id]
    end
    @partial = "../../vendor/plugins/#{plugin_id}/app/views/" + @plugin.settings[:partial]
    @settings = Setting["plugin_#{plugin_id}"]
  end
end
