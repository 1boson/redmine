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

class AttachmentsController < ApplicationController
  layout 'base'
  before_filter :find_project, :check_project_privacy

  # sends an attachment
  def download
    send_file @attachment.diskfile, :filename => @attachment.filename
  rescue
    render_404
  end
    
  # sends an image to be displayed inline
  def show
    render(:nothing => true, :status => 404) and return unless @attachment.diskfile =~ /\.(jpeg|jpg|gif|png)$/i
    send_file @attachment.diskfile, :type => "image/#{$1}", :disposition => 'inline'
  rescue
    render_404
  end
 
private
  def find_project
    @attachment = Attachment.find(params[:id])
    @project = @attachment.project
  rescue
    render_404
  end
end
