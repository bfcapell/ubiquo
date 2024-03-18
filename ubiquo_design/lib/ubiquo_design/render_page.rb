module UbiquoDesign
  module RenderPage

    def self.included(klass)
      klass.helper_method :render_block
    end

    # Check if the current request if a widget request
    def widget_request?
      params[:widget]
    end

    # Returns true if we only have to render one widget
    # Also renders it, so nothing more should be done
    def render_widget_only
      return unless widget_request?
      widget = Widget.find(params[:widget])
      output = render_widget(widget)
      unless performed?
        render :text => output
      end
      true
    end

    def render_page(page)
      cached_widgets = UbiquoDesign.cache_manager.multi_get(page,:scope => self)

      begin
        @blocks = page.blocks.collect do |block|
          block_output = render_block(block.real_block, cached_widgets)
          # Return if block is void (normally, a redirect ocurred)
          return unless block_output
          [block.block_type.to_sym, block_output.join]
        end.to_hash
        render_template_file(page.page_template, page.layout)
      rescue ActionView::MissingTemplate
        if (request.format.in?(Ubiquo::Settings[:ubiquo_design][:rescue_missing_template]) rescue false)
          raise ActionController::RoutingError.new('Not Found')
        else
          raise
        end
      end
    end

    # Renders all the widgets contained in a block
    def render_block(block, cached_widgets = {})
      uhook_collect_widgets(block) do |widget|
        next unless widget.valid?
        (cached_widgets[widget.id] || render_widget(widget)).tap do |output|
          # A widget didn't return an string, return inmediately
          return unless output
        end
      end
    end

    def template_directory
      Rails.env.test? ? File.join(ActiveSupport::TestCase.fixture_path, "templates") :
        Rails.root.join('app', 'views', 'page_templates').to_s
    end

    def render_template_file(key, layout = 'main')
      template_file = File.join(template_directory, "#{key}")
      self.view_paths.unshift(File.dirname(template_file))
      render_output = render(:file => File.basename(template_file), :layout => layout)
      self.view_paths.paths.shift
      render_output
    end

    def varnish_expires_in time
      response.headers['X-RUN-ESI'] = 'true' unless widget_request?
      response.headers['X-VARNISH-TTL'] = time.to_s
    end

    def include_expiration_headers
      format = request.format ? request.format.to_sym : :html

      if format == :rss
        client_cache 0
        server_cache 10.minutes
      else
        if @page
          client_cache @page.client_expiration
          server_cache @page.server_expiration
        end
      end
    end

    def client_cache(time = 5.minutes)
      if time > 0
        expires_in time, :public => true
      else
        response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate, public"
        response.headers["Pragma"]        = "no-cache"
        response.headers["Etag"]          = Time.now.to_i.to_s
        response.headers["Expires"]       = "Fri, 01 Jan 1990 00:00:00 GMT"
      end
    end

    def server_cache(time = 30.minutes)
      varnish_expires_in time if varnish_enabled?
    end

    def varnish_enabled?
      UbiquoDesign.cache_manager == UbiquoDesign::CacheManagers::Varnish
    end

  end
end
