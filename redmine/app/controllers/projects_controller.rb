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

class ProjectsController < ApplicationController
	layout 'base'
	before_filter :find_project, :authorize, :except => [ :index, :list, :add ]
  before_filter :require_admin, :only => [ :add, :destroy ]

  helper :sort
	include SortHelper	
	helper :search_filter
	include SearchFilterHelper	
	helper :custom_fields
	include CustomFieldsHelper   

	def index
		list
		render :action => 'list'
	end

	# Lists public projects
	def list
		sort_init 'projects.name', 'asc'
		sort_update		
		@project_count = Project.count(["public=?", true])		
		@project_pages = Paginator.new self, @project_count,
								15,
								@params['page']								
		@projects = Project.find :all, :order => sort_clause,
						:conditions => ["public=?", true],
						:limit  =>  @project_pages.items_per_page,
						:offset =>  @project_pages.current.offset		
  end
          
  # Add a new project
	def add
		@custom_fields = CustomField::find_all
		@project = Project.new(params[:project])
		if request.post?
			@project.custom_fields = CustomField.find(@params[:custom_field_ids]) if @params[:custom_field_ids]
			if @project.save
				flash[:notice] = 'Project was successfully created.'
				redirect_to :controller => 'admin', :action => 'projects'
			end		
		end	
	end
	
	# Show @project
	def show
    @members = @project.members.find(:all, :include => [:user, :role])
	end

  def settings
		@custom_fields = CustomField::find_all
		@issue_category ||= IssueCategory.new
    @member ||= @project.members.new
    @roles = Role.find_all
    @users = User.find_all - @project.members.find(:all, :include => :user).collect{|m| m.user }
  end
  
	# Edit @project
	def edit
		if request.post?
			@project.custom_fields = CustomField.find(@params[:custom_field_ids]) if @params[:custom_field_ids]
			if @project.update_attributes(params[:project])
				flash[:notice] = 'Project was successfully updated.'
				redirect_to :action => 'settings', :id => @project
      else
        settings
        render :action => 'settings'
			end
		end
  end
  
	# Delete @project
	def destroy
    if request.post? and params[:confirm]
      @project.destroy
      redirect_to :controller => 'admin', :action => 'projects'
    end
	end
	
	# Add a new issue category to @project
	def add_issue_category
		if request.post?
			@issue_category = @project.issue_categories.build(params[:issue_category])
			if @issue_category.save
				redirect_to :action => 'settings', :id => @project
			else
        settings
        render :action => 'settings'
			end
		end
	end	
	
	# Add a new version to @project
	def add_version
		@version = @project.versions.build(params[:version])
		if request.post? and @version.save
      redirect_to :action => 'settings', :id => @project
		end
	end

	# Add a new member to @project
	def add_member
    @member = @project.members.build(params[:member])
		if request.post?
			if @member.save
        flash[:notice] = 'Member was successfully added.'
				redirect_to :action => 'settings', :id => @project
			else		
        settings
        render :action => 'settings'
      end
		end
	end

	# Show members list of @project
	def list_members
		@members = @project.members
	end

	# Add a new document to @project
	def add_document
		@categories = Enumeration::get_values('DCAT')
		@document = @project.documents.build(params[:document])    
		if request.post?			
      # Save the attachment
			if params[:attachment][:file].size > 0
				@attachment = @document.attachments.build(params[:attachment])				
        @attachment.author_id = session[:user].id unless session[:user].nil?
			end      
			if @document.save
				redirect_to :action => 'list_documents', :id => @project
			end		
		end
	end

	# Show documents list of @project
	def list_documents
		@documents = @project.documents
	end

	# Add a new issue to @project
	def add_issue
		@trackers = Tracker.find(:all)
		@priorities = Enumeration::get_values('IPRI')		
		if request.get?
			@issue = @project.issues.build
			@custom_values = @project.custom_fields_for_issues.collect { |x| CustomValue.new(:custom_field => x) }
		else
			# Create the issue and set the author
			@issue = @project.issues.build(params[:issue])
      @issue.author = session[:user] unless session[:user].nil?			
			# Create the document if a file was sent
			if params[:attachment][:file].size > 0
				@attachment = @issue.attachments.build(params[:attachment])				
        @attachment.author_id = session[:user].id unless session[:user].nil?
			end
			@custom_values = @project.custom_fields_for_issues.collect { |x| CustomValue.new(:custom_field => x, :value => params["custom_fields"][x.id.to_s]) }
			@issue.custom_values = @custom_values			
			if @issue.save
        flash[:notice] = "Issue was successfully added."
				Mailer.deliver_issue_add(@issue) if Permission.find_by_controller_and_action(@params[:controller], @params[:action]).mail_enabled?
				redirect_to :action => 'list_issues', :id => @project
			end		
		end	
	end
	
	# Show issues list of @project
	def list_issues
		sort_init 'issues.id', 'desc'
		sort_update
		
		search_filter_criteria 'issues.tracker_id', :values => "Tracker.find(:all)"
		search_filter_criteria 'issues.priority_id', :values => "Enumeration.find(:all, :conditions => ['opt=?','IPRI'])"
		search_filter_criteria 'issues.category_id', :values => "@project.issue_categories"
		search_filter_criteria 'issues.status_id', :values => "IssueStatus.find(:all)"
		search_filter_criteria 'issues.author_id', :values => "User.find(:all)", :label => "display_name"
		search_filter_update if params[:set_filter] or request.post?
						
		@issue_count = @project.issues.count(search_filter_clause)		
		@issue_pages = Paginator.new self, @issue_count,
								15,
								@params['page']								
		@issues =  @project.issues.find :all, :order => sort_clause,
						:include => [ :author, :status, :tracker ],
						:conditions => search_filter_clause,
						:limit  =>  @issue_pages.items_per_page,
						:offset =>  @issue_pages.current.offset								
	end

	# Add a news to @project
	def add_news
    @news = @project.news.build(params[:news])
		if request.post?
			@news.author = session[:user] unless session[:user].nil?
			if @news.save
				redirect_to :action => 'list_news', :id => @project
			end
		end
	end

	# Show news list of @project
	def list_news
    @news_pages, @news = paginate :news, :per_page => 10, :conditions => ["project_id=?", @project.id], :include => :author, :order => "news.created_on DESC"
	end
  
  def add_file  
    if request.post?
      # Save the attachment
      if params[:attachment][:file].size > 0
        @attachment = @project.versions.find(params[:version_id]).attachments.build(params[:attachment])      
        @attachment.author_id = session[:user].id unless session[:user].nil?
        if @attachment.save
          redirect_to :controller => 'projects', :action => 'list_files', :id => @project
        end
      end
    end
    @versions = @project.versions
  end
  
  def list_files
    @versions = @project.versions
  end
  
	# Show changelog of @project
	def changelog
  @fixed_issues = @project.issues.find(:all, 
                                                        :include => [ :fixed_version, :status, :tracker ], 
                                                        :conditions => [ "issue_statuses.is_closed=? and trackers.is_in_chlog=? and issues.fixed_version_id is not null", true, true]
                                                        )
	end

private
	# Find project of id params[:id]
	# if not found, redirect to project list
	# used as a before_filter
	def find_project
		@project = Project.find(params[:id])		
		rescue
			flash[:notice] = 'Project not found.'
			redirect_to :action => 'list'			
	end

end
