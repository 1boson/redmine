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

require File.dirname(__FILE__) + '/../../test_helper'

class ApplicationHelperTest < HelperTestCase
  include ApplicationHelper
  include ActionView::Helpers::TextHelper
  fixtures :projects, :repositories, :changesets, :trackers, :issue_statuses, :issues, :documents, :versions, :wikis, :wiki_pages, :wiki_contents

  def setup
    super
  end
  
  def test_auto_links
    to_test = {
      'http://foo.bar' => '<a class="external" href="http://foo.bar">http://foo.bar</a>',
      'http://foo.bar/~user' => '<a class="external" href="http://foo.bar/~user">http://foo.bar/~user</a>',
      'http://foo.bar.' => '<a class="external" href="http://foo.bar">http://foo.bar</a>.',
      'http://foo.bar/foo.bar#foo.bar.' => '<a class="external" href="http://foo.bar/foo.bar#foo.bar">http://foo.bar/foo.bar#foo.bar</a>.',
      'www.foo.bar' => '<a class="external" href="http://www.foo.bar">www.foo.bar</a>',
      'http://foo.bar/page?p=1&t=z&s=' => '<a class="external" href="http://foo.bar/page?p=1&#38;t=z&#38;s=">http://foo.bar/page?p=1&#38;t=z&#38;s=</a>',
      'http://foo.bar/page#125' => '<a class="external" href="http://foo.bar/page#125">http://foo.bar/page#125</a>'
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end
  
  def test_auto_mailto
    assert_equal '<p><a href="mailto:test@foo.bar" class="email">test@foo.bar</a></p>', 
      textilizable('test@foo.bar')
  end
  
  def test_inline_images
    to_test = {
      '!http://foo.bar/image.jpg!' => '<img src="http://foo.bar/image.jpg" alt="" />',
      'floating !>http://foo.bar/image.jpg!' => 'floating <div style="float:right"><img src="http://foo.bar/image.jpg" alt="" /></div>',
      'with class !(some-class)http://foo.bar/image.jpg!' => 'with class <img src="http://foo.bar/image.jpg" class="some-class" alt="" />',
      'with style !{width:100px;height100px}http://foo.bar/image.jpg!' => 'with style <img src="http://foo.bar/image.jpg" style="width:100px;height100px;" alt="" />',
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end
  
  def test_textile_external_links
    to_test = {
      'This is a "link":http://foo.bar' => 'This is a <a href="http://foo.bar" class="external">link</a>',
      'This is an intern "link":/foo/bar' => 'This is an intern <a href="/foo/bar">link</a>',
      '"link (Link title)":http://foo.bar' => '<a href="http://foo.bar" title="Link title" class="external">link</a>'
    }
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end
  
  def test_redmine_links
    issue_link = link_to('#3', {:controller => 'issues', :action => 'show', :id => 3}, 
                               :class => 'issue', :title => 'Error 281 when updating a recipe (New)')
    
    changeset_link = link_to('r1', {:controller => 'repositories', :action => 'revision', :id => 1, :rev => 1},
                                   :class => 'changeset', :title => 'My very first commit')
    
    document_link = link_to('Test document', {:controller => 'documents', :action => 'show', :id => 1},
                                             :class => 'document')
    
    version_link = link_to('1.0', {:controller => 'versions', :action => 'show', :id => 2},
                                  :class => 'version')
    
    to_test = {
      '#3, #3 and #3.' => "#{issue_link}, #{issue_link} and #{issue_link}.",
      'r1' => changeset_link,
      'document#1' => document_link,
      'document:"Test document"' => document_link,
      'version#2' => version_link,
      'version:1.0' => version_link,
      'version:"1.0"' => version_link,
      # escaping
      '!#3.' => '#3.',
      '!r1' => 'r1',
      '!document#1' => 'document#1',
      '!document:"Test document"' => 'document:"Test document"',
      '!version#2' => 'version#2',
      '!version:1.0' => 'version:1.0',
      '!version:"1.0"' => 'version:"1.0"',
    }
    @project = Project.find(1)
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end
  
  def test_wiki_links
    to_test = {
      '[[CookBook documentation]]' => '<a href="/wiki/ecookbook/CookBook_documentation" class="wiki-page">CookBook documentation</a>',
      '[[Another page|Page]]' => '<a href="/wiki/ecookbook/Another_page" class="wiki-page">Page</a>',
      # page that doesn't exist
      '[[Unknown page]]' => '<a href="/wiki/ecookbook/Unknown_page" class="wiki-page new">Unknown page</a>',
      '[[Unknown page|404]]' => '<a href="/wiki/ecookbook/Unknown_page" class="wiki-page new">404</a>',
      # link to another project wiki
      '[[onlinestore:]]' => '<a href="/wiki/onlinestore/" class="wiki-page">onlinestore</a>',
      '[[onlinestore:|Wiki]]' => '<a href="/wiki/onlinestore/" class="wiki-page">Wiki</a>',
      '[[onlinestore:Start page]]' => '<a href="/wiki/onlinestore/Start_page" class="wiki-page">Start page</a>',
      '[[onlinestore:Start page|Text]]' => '<a href="/wiki/onlinestore/Start_page" class="wiki-page">Text</a>',
      '[[onlinestore:Unknown page]]' => '<a href="/wiki/onlinestore/Unknown_page" class="wiki-page new">Unknown page</a>',
      # escaping
      '![[Another page|Page]]' => '[[Another page|Page]]',
    }
    @project = Project.find(1)
    to_test.each { |text, result| assert_equal "<p>#{result}</p>", textilizable(text) }
  end
  
  def test_macro_hello_world
    text = "{{hello_world}}"
    assert textilizable(text).match(/Hello world!/)
    # escaping
    text = "!{{hello_world}}"
    assert_equal '<p>{{hello_world}}</p>', textilizable(text)
  end
  
  def test_date_format_default
    today = Date.today
    Setting.date_format = ''    
    assert_equal l_date(today), format_date(today)
  end
  
  def test_date_format
    today = Date.today
    Setting.date_format = '%d %m %Y'
    assert_equal today.strftime('%d %m %Y'), format_date(today)
  end
  
  def test_time_format_default
    now = Time.now
    Setting.date_format = ''
    Setting.time_format = ''    
    assert_equal l_datetime(now), format_time(now)
    assert_equal l_time(now), format_time(now, false)
  end
  
  def test_time_format
    now = Time.now
    Setting.date_format = '%d %m %Y'
    Setting.time_format = '%H %M'
    assert_equal now.strftime('%d %m %Y %H %M'), format_time(now)
    assert_equal now.strftime('%H %M'), format_time(now, false)
  end
end
