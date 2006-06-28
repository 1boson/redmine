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

class NewsController < ApplicationController
	layout 'base'
	before_filter :find_project, :authorize

  def show
  end

  def edit
    if request.post? and @news.update_attributes(params[:news])
      flash[:notice] = 'News was successfully updated.'
      redirect_to :action => 'show', :id => @news
    end
  end

	def destroy
		@news.destroy
		redirect_to :controller => 'projects', :action => 'list_news', :id => @project
	end
  
private
	def find_project
    @news = News.find(params[:id])
		@project = @news.project
	end  
end
