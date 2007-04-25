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

class Changeset < ActiveRecord::Base
  belongs_to :repository
  has_many :changes, :dependent => :delete_all
  has_and_belongs_to_many :issues
  
  validates_presence_of :repository_id, :revision, :committed_on, :commit_date
  validates_numericality_of :revision, :only_integer => true
  validates_uniqueness_of :revision, :scope => :repository_id
  
  def committed_on=(date)
    self.commit_date = date
    super
  end
  
  def after_create
    scan_comment_for_issue_ids
  end
  
  def scan_comment_for_issue_ids
    return if comments.blank?
    # keywords used to reference issues
    ref_keywords = Setting.commit_ref_keywords.downcase.split(",")
    # keywords used to fix issues
    fix_keywords = Setting.commit_fix_keywords.downcase.split(",")
    # status applied
    fix_status = IssueStatus.find_by_id(Setting.commit_fix_status_id)
    
    kw_regexp = (ref_keywords + fix_keywords).collect{|kw| Regexp.escape(kw.strip)}.join("|")
    return if kw_regexp.blank?
    
    # remove any associated issues
    self.issues.clear
    
    comments.scan(Regexp.new("(#{kw_regexp})[\s:]+(([\s,;&]*#?\\d+)+)", Regexp::IGNORECASE)).each do |match|
      action = match[0]
      target_issue_ids = match[1].scan(/\d+/)
      target_issues = repository.project.issues.find_all_by_id(target_issue_ids)
      if fix_status && fix_keywords.include?(action.downcase)
        # update status of issues
        logger.debug "Issues fixed by changeset #{self.revision}: #{issue_ids.join(', ')}." if logger && logger.debug?
        target_issues.each do |issue|
          # don't change the status is the issue is already closed
          next if issue.status.is_closed?
          issue.status = fix_status
          issue.save
        end
      end
      self.issues << target_issues
    end
  end
end
