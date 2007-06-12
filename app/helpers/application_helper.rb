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

class RedCloth
  # Patch for RedCloth.  Fixed in RedCloth r128 but _why hasn't released it yet.
  # <a href="http://code.whytheluckystiff.net/redcloth/changeset/128">http://code.whytheluckystiff.net/redcloth/changeset/128</a>
  def hard_break( text ) 
    text.gsub!( /(.)\n(?!\n|\Z| *([#*=]+(\s|$)|[{|]))/, "\\1<br />" ) if hard_breaks 
  end 
end

module ApplicationHelper

  # Return current logged in user or nil
  def loggedin?
    @logged_in_user
  end
  
  # Return true if user is logged in and is admin, otherwise false
  def admin_loggedin?
    @logged_in_user and @logged_in_user.admin?
  end

  # Return true if user is authorized for controller/action, otherwise false
  def authorize_for(controller, action)  
    # check if action is allowed on public projects
    if @project.is_public? and Permission.allowed_to_public "%s/%s" % [ controller, action ]
      return true
    end
    # check if user is authorized    
    if @logged_in_user and (@logged_in_user.admin? or Permission.allowed_to_role( "%s/%s" % [ controller, action ], @logged_in_user.role_for_project(@project)  )  )
      return true
    end
    return false
  end

  # Display a link if user is authorized
  def link_to_if_authorized(name, options = {}, html_options = nil, *parameters_for_method_reference)
    link_to(name, options, html_options, *parameters_for_method_reference) if authorize_for(options[:controller], options[:action])
  end

  # Display a link to user's account page
  def link_to_user(user)
    link_to user.display_name, :controller => 'account', :action => 'show', :id => user
  end
  
  def link_to_issue(issue)
    link_to "#{issue.tracker.name} ##{issue.id}", :controller => "issues", :action => "show", :id => issue
  end
  
  def toggle_link(name, id, options={})
    onclick = "Element.toggle('#{id}'); "
    onclick << (options[:focus] ? "Form.Element.focus('#{options[:focus]}'); " : "this.blur(); ")
    onclick << "return false;"
    link_to(name, "#", :onclick => onclick)
  end
  
  def image_to_function(name, function, html_options = {})
    html_options.symbolize_keys!
    tag(:input, html_options.merge({ 
        :type => "image", :src => image_path(name), 
        :onclick => (html_options[:onclick] ? "#{html_options[:onclick]}; " : "") + "#{function};" 
        }))
  end
  
  def format_date(date)
    l_date(date) if date
  end
  
  def format_time(time)
    l_datetime((time.is_a? String) ? time.to_time : time) if time
  end
  
  def day_name(day)
    l(:general_day_names).split(',')[day-1]
  end
  
  def month_name(month)
    l(:actionview_datehelper_select_month_names).split(',')[month-1]
  end

  def pagination_links_full(paginator, options={}, html_options={})
    html = ''    
    html << link_to_remote(('&#171; ' + l(:label_previous)), 
                            {:update => "content", :url => options.merge(:page => paginator.current.previous)},
                            {:href => url_for(:params => options.merge(:page => paginator.current.previous))}) + ' ' if paginator.current.previous
                            
    html << (pagination_links_each(paginator, options) do |n|
      link_to_remote(n.to_s, 
                      {:url => {:params => options.merge(:page => n)}, :update => 'content'},
                      {:href => url_for(:params => options.merge(:page => n))})
    end || '')
    
    html << ' ' + link_to_remote((l(:label_next) + ' &#187;'), 
                                 {:update => "content", :url => options.merge(:page => paginator.current.next)},
                                 {:href => url_for(:params => options.merge(:page => paginator.current.next))}) if paginator.current.next
    html  
  end
  
  # textilize text according to system settings and RedCloth availability
  def textilizable(text, options = {})
    return "" if text.blank?
    
    # different methods for formatting wiki links
    case options[:wiki_links]
    when :local
      # used for local links to html files
      format_wiki_link = Proc.new {|title| "#{title}.html" }
    when :anchor
      # used for single-file wiki export
      format_wiki_link = Proc.new {|title| "##{title}" }
    else
      if @project
        format_wiki_link = Proc.new {|title| url_for :controller => 'wiki', :action => 'index', :id => @project, :page => title }
      else
        format_wiki_link = Proc.new {|title| title }
      end
    end
    
    # turn wiki links into textile links: 
    # example:
    #   [[link]] -> "link":link
    #   [[link|title]] -> "title":link
    text = text.gsub(/\[\[([^\]\|]+)(\|([^\]\|]+))?\]\]/) {|m| "\"#{$3 || $1}\":" + format_wiki_link.call(Wiki.titleize($1)) }

    # turn issue ids into links
    # example:
    #   #52 -> <a href="/issues/show/52">#52</a>
    text = text.gsub(/#(\d+)(?=\b)/) {|m| link_to "##{$1}", :controller => 'issues', :action => 'show', :id => $1}
       
    # turn revision ids into links (@project needed)
    # example:
    #   r52 -> <a href="/repositories/revision/6?rev=52">r52</a> (@project.id is 6)
    text = text.gsub(/(?=\b)r(\d+)(?=\b)/) {|m| link_to "r#{$1}", :controller => 'repositories', :action => 'revision', :id => @project.id, :rev => $1} if @project
    
    # when using an image link, try to use an attachment, if possible
    attachments = options[:attachments]
    if attachments
      text = text.gsub(/!([<>=]*)(\S+\.(gif|jpg|jpeg|png))!/) do |m|
        align = $1
        filename = $2
        rf = Regexp.new(filename,  Regexp::IGNORECASE)
        # search for the picture in attachments
        if found = attachments.detect { |att| att.filename =~ rf }
          image_url = url_for :controller => 'attachments', :action => 'show', :id => found.id
          "!#{align}#{image_url}!"
        else
          "!#{align}#{filename}!"
        end
      end
    end

    # finally textilize text
    @do_textilize ||= (Setting.text_formatting == 'textile') && (ActionView::Helpers::TextHelper.method_defined? "textilize")
    text = @do_textilize ? auto_link(RedCloth.new(text, [:hard_breaks]).to_html) : simple_format(auto_link(h(text)))
  end
  
  def error_messages_for(object_name, options = {})
    options = options.symbolize_keys
    object = instance_variable_get("@#{object_name}")
    if object && !object.errors.empty?
      # build full_messages here with controller current language
      full_messages = []
      object.errors.each do |attr, msg|
        next if msg.nil?
        msg = msg.first if msg.is_a? Array
        if attr == "base"
          full_messages << l(msg)
        else
          full_messages << "&#171; " + (l_has_string?("field_" + attr) ? l("field_" + attr) : object.class.human_attribute_name(attr)) + " &#187; " + l(msg) unless attr == "custom_values"
        end
      end
      # retrieve custom values error messages
      if object.errors[:custom_values]
        object.custom_values.each do |v| 
          v.errors.each do |attr, msg|
            next if msg.nil?
            msg = msg.first if msg.is_a? Array
            full_messages << "&#171; " + v.custom_field.name + " &#187; " + l(msg)
          end
        end
      end      
      content_tag("div",
        content_tag(
          options[:header_tag] || "h2", lwr(:gui_validation_error, full_messages.length) + " :"
        ) +
        content_tag("ul", full_messages.collect { |msg| content_tag("li", msg) }),
        "id" => options[:id] || "errorExplanation", "class" => options[:class] || "errorExplanation"
      )
    else
      ""
    end
  end
  
  def lang_options_for_select(blank=true)
    (blank ? [["(auto)", ""]] : []) + 
      GLoc.valid_languages.collect{|lang| [ ll(lang.to_s, :general_lang_name), lang.to_s]}.sort{|x,y| x.first <=> y.first }
  end
  
  def label_tag_for(name, option_tags = nil, options = {})
    label_text = l(("field_"+field.to_s.gsub(/\_id$/, "")).to_sym) + (options.delete(:required) ? @template.content_tag("span", " *", :class => "required"): "")
    content_tag("label", label_text)
  end
  
  def labelled_tabular_form_for(name, object, options, &proc)
    options[:html] ||= {}
    options[:html].store :class, "tabular"
    form_for(name, object, options.merge({ :builder => TabularFormBuilder, :lang => current_language}), &proc)
  end
  
  def check_all_links(form_name)
    link_to_function(l(:button_check_all), "checkAll('#{form_name}', true)") +
    " | " +
    link_to_function(l(:button_uncheck_all), "checkAll('#{form_name}', false)")   
  end
  
  def calendar_for(field_id)
    image_tag("calendar.png", {:id => "#{field_id}_trigger",:class => "calendar-trigger"}) +
    javascript_tag("Calendar.setup({inputField : '#{field_id}', ifFormat : '%Y-%m-%d', button : '#{field_id}_trigger' });")
  end
  
  def wikitoolbar_for(field_id)
    return '' unless Setting.text_formatting == 'textile'
    javascript_include_tag('jstoolbar') + javascript_tag("var toolbar = new jsToolBar($('#{field_id}')); toolbar.draw();")
  end
end

class TabularFormBuilder < ActionView::Helpers::FormBuilder
  include GLoc
  
  def initialize(object_name, object, template, options, proc)
    set_language_if_valid options.delete(:lang)
    @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc        
  end      
      
  (field_helpers - %w(radio_button hidden_field) + %w(date_select)).each do |selector|
    src = <<-END_SRC
    def #{selector}(field, options = {}) 
      return super if options.delete :no_label
      label_text = l(options[:label]) if options[:label]
      label_text ||= l(("field_"+field.to_s.gsub(/\_id$/, "")).to_sym)
      label_text << @template.content_tag("span", " *", :class => "required") if options.delete(:required)
      label = @template.content_tag("label", label_text, 
                    :class => (@object && @object.errors[field] ? "error" : nil), 
                    :for => (@object_name.to_s + "_" + field.to_s))
      label + super
    end
    END_SRC
    class_eval src, __FILE__, __LINE__
  end
  
  def select(field, choices, options = {}, html_options = {}) 
    label_text = l(("field_"+field.to_s.gsub(/\_id$/, "")).to_sym) + (options.delete(:required) ? @template.content_tag("span", " *", :class => "required"): "")
    label = @template.content_tag("label", label_text, 
                  :class => (@object && @object.errors[field] ? "error" : nil), 
                  :for => (@object_name.to_s + "_" + field.to_s))
    label + super
  end

end

