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

desc 'Mantis migration script'

require 'active_record'
require 'iconv'
require 'pp'

task :migrate_from_mantis => :environment do
  
  module MantisMigrate
   
      default_status = IssueStatus.default
      assigned_status = IssueStatus.find_by_position(2)
      resolved_status = IssueStatus.find_by_position(3)
      feedback_status = IssueStatus.find_by_position(4)
      closed_status = IssueStatus.find :first, :conditions => { :is_closed => true }
      STATUS_MAPPING = {10 => default_status,  # new
                        20 => feedback_status, # feedback
                        30 => default_status,  # acknowledged
                        40 => default_status,  # confirmed
                        50 => assigned_status, # assigned
                        80 => resolved_status, # resolved
                        90 => closed_status    # closed
                        }
                        
      priorities = Enumeration.get_values('IPRI')
      PRIORITY_MAPPING = {10 => priorities[1], # none
                          20 => priorities[1], # low
                          30 => priorities[2], # normal
                          40 => priorities[3], # high
                          50 => priorities[4], # urgent
                          60 => priorities[5]  # immediate
                          }
    
      TARGET_TRACKER = Tracker.find :first
      
      default_role = Role.find_by_position(3)
      manager_role = Role.find_by_position(1)
      developer_role = Role.find_by_position(2)
      ROLE_MAPPING = {10 => default_role,   # viewer
                      25 => default_role,   # reporter
                      40 => default_role,   # updater
                      55 => developer_role, # developer
                      70 => manager_role,   # manager
                      90 => manager_role    # administrator
                      }
      
      CUSTOM_FIELD_TYPE_MAPPING = {0 => 'string', # String
                                   1 => 'int',    # Numeric
                                   2 => 'int',    # Float
                                   3 => 'list',   # Enumeration
                                   4 => 'string', # Email
                                   5 => 'bool',   # Checkbox
                                   6 => 'list',   # List
                                   7 => 'list',   # Multiselection list
                                   8 => 'date',   # Date
                                   }
                                   
      RELATION_TYPE_MAPPING = {1 => IssueRelation::TYPE_RELATES,    # related to
                               2 => IssueRelation::TYPE_RELATES,    # parent of
                               3 => IssueRelation::TYPE_RELATES,    # child of
                               0 => IssueRelation::TYPE_DUPLICATES, # duplicate of
                               4 => IssueRelation::TYPE_DUPLICATES  # has duplicate
                               }
                                                                   
    class MantisUser < ActiveRecord::Base
      set_table_name :mantis_user_table
      
      def firstname
        realname.blank? ? username : realname.split.first[0..29]
      end
      
      def lastname
        realname.blank? ? username : realname.split[1..-1].join(' ')[0..29]
      end
      
      def email
        if read_attribute(:email).match(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i)
          read_attribute(:email)
        else
          "#{username}@foo.bar"
        end
      end
    end
    
    class MantisProject < ActiveRecord::Base
      set_table_name :mantis_project_table
      has_many :versions, :class_name => "MantisVersion", :foreign_key => :project_id
      has_many :categories, :class_name => "MantisCategory", :foreign_key => :project_id
      has_many :news, :class_name => "MantisNews", :foreign_key => :project_id
      has_many :members, :class_name => "MantisProjectUser", :foreign_key => :project_id
      
      def name
        read_attribute(:name)[0..29].gsub(/[^\w\s\'\-]/, '-')
      end
      
      def description
        read_attribute(:description).blank? ? read_attribute(:name) : read_attribute(:description)[0..254]
      end
      
      def identifier
        read_attribute(:name).underscore[0..11].gsub(/[^a-z0-9\-]/, '-')
      end
    end
    
    class MantisVersion < ActiveRecord::Base
      set_table_name :mantis_project_version_table
      
      def version
        read_attribute(:version)[0..29]
      end
      
      def description
        read_attribute(:description)[0..254]
      end
    end
    
    class MantisCategory < ActiveRecord::Base
      set_table_name :mantis_project_category_table
    end
    
    class MantisProjectUser < ActiveRecord::Base
      set_table_name :mantis_project_user_list_table
    end
    
    class MantisBug < ActiveRecord::Base
      set_table_name :mantis_bug_table
      belongs_to :bug_text, :class_name => "MantisBugText", :foreign_key => :bug_text_id
      has_many :bug_notes, :class_name => "MantisBugNote", :foreign_key => :bug_id
      has_many :bug_files, :class_name => "MantisBugFile", :foreign_key => :bug_id
      has_many :bug_monitors, :class_name => "MantisBugMonitor", :foreign_key => :bug_id
    end
    
    class MantisBugText < ActiveRecord::Base
      set_table_name :mantis_bug_text_table
      
      # Adds Mantis steps_to_reproduce and additional_information fields
      # to description if any
      def full_description
        full_description = description
        full_description += "\n\n*Steps to reproduce:*\n\n#{steps_to_reproduce}" unless steps_to_reproduce.blank?
        full_description += "\n\n*Additional information:*\n\n#{additional_information}" unless additional_information.blank?
        full_description
      end
    end
    
    class MantisBugNote < ActiveRecord::Base
      set_table_name :mantis_bugnote_table
      belongs_to :bug, :class_name => "MantisBug", :foreign_key => :bug_id
      belongs_to :bug_note_text, :class_name => "MantisBugNoteText", :foreign_key => :bugnote_text_id
    end
    
    class MantisBugNoteText < ActiveRecord::Base
      set_table_name :mantis_bugnote_text_table
    end
    
    class MantisBugFile < ActiveRecord::Base
      set_table_name :mantis_bug_file_table
      
      def size
        filesize
      end
      
      def original_filename
        filename
      end
      
      def content_type
        file_type
      end
      
      def read
        content
      end
    end
    
    class MantisBugRelationship < ActiveRecord::Base
      set_table_name :mantis_bug_relationship_table
    end
    
    class MantisBugMonitor < ActiveRecord::Base
      set_table_name :mantis_bug_monitor_table
    end
    
    class MantisNews < ActiveRecord::Base
      set_table_name :mantis_news_table
    end
    
    class MantisCustomField < ActiveRecord::Base
      set_table_name :mantis_custom_field_table
      set_inheritance_column :none  
      has_many :values, :class_name => "MantisCustomFieldString", :foreign_key => :field_id
      has_many :projects, :class_name => "MantisCustomFieldProject", :foreign_key => :field_id
      
      def format
        read_attribute :type
      end
      
      def name
        read_attribute(:name)[0..29].gsub(/[^\w\s\'\-]/, '-')
      end
    end
    
    class MantisCustomFieldProject < ActiveRecord::Base
      set_table_name :mantis_custom_field_project_table  
    end
    
    class MantisCustomFieldString < ActiveRecord::Base
      set_table_name :mantis_custom_field_string_table  
    end
  
  
    def self.migrate
          
      # Users
      print "Migrating users"
      User.delete_all "login <> 'admin'"
      users_map = {}
      users_migrated = 0
      MantisUser.find(:all).each do |user|
    	u = User.new :firstname => encode(user.firstname), 
    				 :lastname => encode(user.lastname),
    				 :mail => user.email,
    				 :last_login_on => user.last_visit
    	u.login = user.username
    	u.password = 'mantis'
    	u.status = User::STATUS_LOCKED if user.enabled != 1
    	u.admin = true if user.access_level == 90
    	next unless u.save
    	users_migrated += 1
    	users_map[user.id] = u.id
    	print '.'
      end
      puts
    
      # Projects
      print "Migrating projects"
      Project.destroy_all
      projects_map = {}
      versions_map = {}
      categories_map = {}
      MantisProject.find(:all).each do |project|
    	p = Project.new :name => encode(project.name), 
                        :description => encode(project.description)
    	p.identifier = project.identifier
    	next unless p.save
    	projects_map[project.id] = p.id
    	print '.'
    	
    	# Project members
    	project.members.each do |member|
          m = Member.new :user => User.find_by_id(users_map[member.user_id]),
    	                 :role => ROLE_MAPPING[member.access_level] || default_role
    	  m.project = p
    	  m.save
    	end	
    	
    	# Project versions
    	project.versions.each do |version|
          v = Version.new :name => encode(version.version),
                          :description => encode(version.description),
                          :effective_date => version.date_order.to_date
          v.project = p
          v.save
          versions_map[version.id] = v.id
    	end
    	
    	# Project categories
    	project.categories.each do |category|
          g = IssueCategory.new :name => category.category
          g.project = p
          g.save
          categories_map[category.category] = g.id
    	end
      end	
      puts	
    
      # Bugs
      print "Migrating bugs"
      Issue.destroy_all
      issues_map = {}
      MantisBug.find(:all).each do |bug|
        next unless projects_map[bug.project_id]
    	i = Issue.new :project_id => projects_map[bug.project_id], 
                      :subject => encode(bug.summary),
                      :description => encode(bug.bug_text.full_description),
                      :priority => PRIORITY_MAPPING[bug.priority],
                      :created_on => bug.date_submitted,
                      :updated_on => bug.last_updated
    	i.author = User.find_by_id(users_map[bug.reporter_id])
    	i.assigned_to = User.find_by_id(users_map[bug.handler_id]) if bug.handler_id && users_map[bug.handler_id]
    	i.category = IssueCategory.find_by_project_id_and_name(i.project_id, bug.category) unless bug.category.blank?
    	i.fixed_version = Version.find_by_project_id_and_name(i.project_id, bug.fixed_in_version) unless bug.fixed_in_version.blank?
    	i.status = STATUS_MAPPING[bug.status] || default_status
    	i.tracker = TARGET_TRACKER
    	next unless i.save
    	issues_map[bug.id] = i.id
    	print '.'
    	
    	# Bug notes
    	bug.bug_notes.each do |note|
          n = Journal.new :notes => encode(note.bug_note_text.note),
                          :created_on => note.date_submitted
          n.user = User.find_by_id(users_map[note.reporter_id])
          n.journalized = i
          n.save
    	end
    	
        # Bug files
        bug.bug_files.each do |file|
          a = Attachment.new :created_on => file.date_added
          a.file = file
          a.author = User.find :first
          a.container = i
          a.save
        end
        
        # Bug monitors
        bug.bug_monitors.each do |monitor|
          i.add_watcher(User.find_by_id(users_map[monitor.user_id]))
        end
      end
      puts
      
      # Bug relationships
      print "Migrating bug relations"
      MantisBugRelationship.find(:all).each do |relation|
        next unless issues_map[relation.source_bug_id] && issues_map[relation.destination_bug_id]
        r = IssueRelation.new :relation_type => RELATION_TYPE_MAPPING[relation.relationship_type]
        r.issue_from = Issue.find_by_id(issues_map[relation.source_bug_id])
        r.issue_to = Issue.find_by_id(issues_map[relation.destination_bug_id])
        pp r unless r.save
        print '.'
      end
      puts
      
      # News
      print "Migrating news"
      News.destroy_all
      MantisNews.find(:all, :conditions => 'project_id > 0').each do |news|
        next unless projects_map[news.project_id]
        n = News.new :project_id => projects_map[news.project_id],
                     :title => encode(news.headline[0..59]),
                     :description => encode(news.body),
                     :created_on => news.date_posted
        n.author = User.find_by_id(users_map[news.poster_id])
        n.save
        print '.'
      end
      puts
      
      # Custom fields
      print "Migrating custom fields"
      IssueCustomField.destroy_all
      MantisCustomField.find(:all).each do |field|
        f = IssueCustomField.new :name => field.name[0..29],
                                 :field_format => CUSTOM_FIELD_TYPE_MAPPING[field.format],
                                 :min_length => field.length_min,
                                 :max_length => field.length_max,
                                 :regexp => field.valid_regexp,
                                 :possible_values => field.possible_values.split('|'),
                                 :is_required => (field.require_report > 0)
        next unless f.save
        print '.'
        
        # Trackers association
        f.trackers = Tracker.find :all
        
        # Projects association
        field.projects.each do |project|
          f.projects << Project.find_by_id(projects_map[project.project_id]) if projects_map[project.project_id]
        end
        
        # Values
        field.values.each do |value|
          v = CustomValue.new :custom_field_id => f.id,
                              :value => value.value
          v.customized = Issue.find_by_id(issues_map[value.bug_id]) if issues_map[value.bug_id]
          v.save
        end unless f.new_record?
      end
      puts
    
      puts
      puts "Users:           #{users_migrated}/#{MantisUser.count}"
      puts "Projects:        #{Project.count}/#{MantisProject.count}"
      puts "Memberships:     #{Member.count}/#{MantisProjectUser.count}"
      puts "Versions:        #{Version.count}/#{MantisVersion.count}"
      puts "Categories:      #{IssueCategory.count}/#{MantisCategory.count}"
      puts "Bugs:            #{Issue.count}/#{MantisBug.count}"
      puts "Bug notes:       #{Journal.count}/#{MantisBugNote.count}"
      puts "Bug files:       #{Attachment.count}/#{MantisBugFile.count}"
      puts "Bug relations:   #{IssueRelation.count}/#{MantisBugRelationship.count}"
      puts "Bug monitors:    #{Watcher.count}/#{MantisBugMonitor.count}"
      puts "News:            #{News.count}/#{MantisNews.count}"
      puts "Custom fields:   #{IssueCustomField.count}/#{MantisCustomField.count}"
    end
  
    def self.encoding(charset)
      @ic = Iconv.new('UTF-8', charset)
    rescue Iconv::InvalidEncoding
      return false      
    end
    
    def self.establish_connection(params)
      constants.each do |const|
        klass = const_get(const)
        next unless klass.respond_to? 'establish_connection'
        klass.establish_connection params
      end
    end
    
  private
    def self.encode(text)
      @ic.iconv text
    rescue
      text
    end
  end
  
  puts
  puts "WARNING: Your Redmine data will be deleted during this process."
  print "Are you sure you want to continue ? [y/N] "
  break unless STDIN.gets.match(/^y$/i)
  
  # Default Mantis database settings
  db_params = {:adapter => 'mysql', 
               :database => 'bugtracker', 
               :host => 'localhost', 
               :username => 'root', 
               :password => '' }

  puts				
  puts "Please enter settings for your Mantis database"  
  [:adapter, :host, :database, :username, :password].each do |param|
    print "#{param} [#{db_params[param]}]: "
    value = STDIN.gets.chomp!
    db_params[param] = value unless value.blank?
  end
    
  while true
    print "encoding [ISO-8859-1]: "
    encoding = STDIN.gets.chomp!
    encoding = 'ISO-8859-1' if encoding.blank?
    break if MantisMigrate.encoding encoding
    puts "Invalid encoding!"
  end
  puts
  
  # Make sure bugs can refer bugs in other projects
  Setting.cross_project_issue_relations = 1
  
  MantisMigrate.establish_connection db_params
  MantisMigrate.migrate
end
