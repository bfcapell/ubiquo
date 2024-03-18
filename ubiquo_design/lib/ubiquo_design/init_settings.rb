# -*- encoding: utf-8 -*-

Ubiquo::Plugin.register(:ubiquo_design, :plugin => UbiquoDesign) do |config|
  config.add :pages_elements_per_page
  config.add_inheritance :pages_elements_per_page, :elements_per_page
  config.add :design_access_control, lambda {
    access_control :DEFAULT => "design_management"
  }
  config.add :design_permit, lambda {
    permit?("design_management")
  }
  config.add :static_pages_permit, lambda {
    permit?("static_pages_management")
  }
  config.add :page_string_filter_enabled, true
  config.add :pages_default_order_field, 'pages.url_name'
  config.add :pages_default_sort_order, 'ASC'
  config.add :widget_tabs_mode, :auto
  config.add :allow_page_preview, true
  config.add :connector, :standard

  config.add :cache_manager_class, lambda {
    UbiquoDesign::CacheManagers::RubyHash
  }

  config.add :memcache, { :server => '127.0.0.1', :timeout => 0 }
  config.add :generic_models, []
  config.add :block_type_for_static_section_widget, 'main'
  config.add :widget_ttl, 10.minutes
  config.add :page_ttl, {
    :client => {
      :minimum => 0.minutes,
      :default => 0.minutes
    },
    :server => {
      :minimum => 1.minute,
      :default => 10.minutes
    }
  }
  config.add(:async_varnish_expiration, false)
  config.add :page_can_be_expired?, lambda {|page, user|
    true
  }
  config.add :expiration_permit, lambda{
    permit?("expiration_management")
  }
  config.add(:public_host, lambda{|options| 'replaceme.com'})
  config.add :rescue_missing_template, []
end

groups = Ubiquo::Settings.get :model_groups
Ubiquo::Settings.set :model_groups, groups.merge(
  :ubiquo_design => %w{blocks widgets pages}
)
