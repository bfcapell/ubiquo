class Ubiquo::AssetsController < UbiquoController
  ubiquo_config_call :assets_access_control, {:context => :ubiquo_media}
  before_filter :load_asset_visibilities
  before_filter :load_asset_types

  # GET /assets
  # GET /assets.xml
  def index
    order_by = params[:order_by] || Ubiquo::Settings.context(:ubiquo_media).get(:assets_default_order_field)
    sort_order = params[:sort_order] || Ubiquo::Settings.context(:ubiquo_media).get(:assets_default_sort_order)
    per_page = params[:per_page] || Ubiquo::Settings.context(:ubiquo_media).get(:assets_elements_per_page)

    filters = {
      "filter_created_start" => params[:filter_created_start],
      "filter_created_end" => params[:filter_created_end], :time_offset => 1.day,
      "per_page" => per_page,
      "order_by" => order_by,
      "sort_order" => sort_order
    }.merge(uhook_index_filters)

    @assets_pages, @assets = uhook_index_search_subject.paginated_filtered_search(params.merge(filters))

    respond_to do |format|
      format.html{ } # index.html.erb
      format.xml{
        render :xml => @assets
      }
    end
  end

  # GET /assets/new
  # GET /assets/new.xml
  def new
    @asset = uhook_new_asset

    respond_to do |format|
      format.html{ } # new.html.erb
      format.xml{ render :xml => @asset }
    end
  end

  # GET /assets/1/edit
  def edit
    @asset = Asset.find(params[:id])
    return if uhook_edit_asset(@asset) == false
  end

  # POST /assets
  # POST /assets.xml
  def create
    counter = params.delete(:counter)
    field = params.delete(:field)
    visibility = get_visibility(params)
    asset_visibility = "asset_#{visibility}".classify.constantize
    @asset = uhook_create_asset asset_visibility
    ok = @asset.save
    if ok && params[:accepted_types]
      if !params[:accepted_types].include?( @asset.asset_type.key )
        ok = false
        @asset.destroy
        @asset.errors[:base] << t("ubiquo.media.invalid_asset_type")
      end
    end
    respond_to do |format|
      if ok
        format.html do
          flash[:notice] = t('ubiquo.media.asset_created')
          return if check_redirects(@asset)
          redirect_to(ubiquo.assets_path)
        end
        format.xml  { render :xml => @asset, :status => :created, :location => @asset }
        format.js {
          responds_to_parent do
            render :update do |page|
              page << "media_fields.add_element('#{field}',null,#{@asset.id},"+
                "#{@asset.name.to_s.to_json}, #{counter.to_json}, "+
                "#{thumbnail_url(@asset).to_json},"+
                "#{view_asset_link(@asset).to_json},null,"+
                "{advanced_form:#{advanced_asset_form_for(@asset).to_json}});"
              # Here we set @asset to be a new asset, to render the partial form with empty values
              saved_asset = @asset
              @asset = asset_visibility.new
              page.replace_html(
                "add_#{counter}",
                :partial => "ubiquo/asset_relations/asset_form",
                :locals => {
                  :counter => counter,
                  :field => field,
                  :visibility => visibility,
                  :accepted_types => params[:accepted_types]
                })
              @asset = saved_asset
            end
          end
        }
      else
        format.html {
          flash[:error] = t('ubiquo.media.asset_create_error')
          render :action => "new"
        }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
        format.js {
          flash.now[:error] = t('ubiquo.media.asset_create_error')
          responds_to_parent do
            render :update do |page|
              page.replace_html(
                "add_#{counter}",
                :partial => "ubiquo/asset_relations/asset_form",
                :locals => {
                  :field => field,
                  :counter => counter,
                  :visibility => visibility,
                  :accepted_types => params[:accepted_types]
                })
            end
          end
        }
      end
    end
  end

  # PUT /assets/1
  # PUT /assets/1.xml
  def update
    @asset = Asset.find(params[:id])
    respond_to do |format|
      if @asset.update_attributes(params[:asset])
        flash[:notice] = t('ubiquo.media.asset_updated')
        return if check_redirects(@asset)
        format.html { redirect_to(ubiquo.assets_path) }
        format.xml  { head :ok }
      else
        flash[:error] = t('ubiquo.media.asset_update_error')
        format.html { render :action => "edit" }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /assets/1
  # DELETE /assets/1.xml
  def destroy
    @asset = Asset.find(params[:id])
    if uhook_destroy_asset(@asset)
      flash[:notice] = t('ubiquo.media.asset_removed')
    else
      flash[:error] = t('ubiquo.media.asset_remove_error')
    end

    respond_to do |format|
      format.html { redirect_to(ubiquo.assets_path) }
      format.xml  { head :ok }
    end
  end

  # GET /assets
  def search
    @field = params[:field]
    @counter = params[:counter]
    @search_text = params[:text]
    @page = params[:page] || 1
    per_page = params[:per_page] || Ubiquo::Settings.context(:ubiquo_media).get(:media_selector_list_size)

    filters = {
      "filter_type" => params[:asset_type_id],
      "filter_text" => @search_text,
      "filter_visibility" => params[:visibility],
      :per_page => per_page,
      :page => @page,
      "order_by" => order_by = params[:order_by] || Ubiquo::Settings.context(:ubiquo_media).get(:assets_default_order_field),
      "sort_order" => "desc"
    }.merge(uhook_index_filters)
    @assets_pages, @assets = uhook_index_search_subject.paginated_filtered_search(filters)
  end

  # GET /assets/1/advanced_edit
  def advanced_edit
    @asset = Asset.find(params[:id])
    if !@asset.is_resizeable?
      flash[:error] = t('ubiquo.media.asset_not_resizeable')
      redirect_to(ubiquo.assets_path)
    else
      render :layout => false
    end
  end

  # PUT /assets/1/advanced_update
  def advanced_update
    @asset = Asset.find(params[:id])
    errors = !@asset.is_resizeable? || !params[:crop_resize]

    unless params[:crop_resize_save_as_new].blank?
      # "find" method is used instead of @asset directly because with @asset doesn't work
      original_asset = Asset.find(@asset.id)
      @asset = original_asset.dup
      @asset.name = params[:asset_name] || @asset.name
      @asset.save!
    end

    @asset.keep_backup = ( params[:asset][:keep_backup] rescue Ubiquo::Settings.context(:ubiquo_media).get(:assets_default_keep_backup))
    errors ||= !@asset.save

    asset_area = nil
    if params[:operation_type] != "original"
      # Dont save original if crop is not on original, and viceversa
      params[:crop_resize].delete(:original)
      #Save asset_areas
      params[:crop_resize].each do |style, values|
        asset_area = @asset.asset_areas.find_by_style(style)
        if asset_area
          asset_area.update_attributes( values )
        else
          asset_area = @asset.asset_areas.new(
            :style => style,
            :width => values["width"],
            :height => values["height"],
            :top => values["top"],
            :left => values["left"]
          )
          asset_area.save
        end
        if !asset_area.errors.empty?
          errors = true
          break
        end
      end unless errors
      unless errors
        @asset.resource.reprocess!
        @asset.touch
      end
    else
      if params[:crop_resize]["original"].find{|k,v|v.to_i > 0}
        begin
          AssetArea.original_crop! params[:crop_resize]["original"].merge(
            :asset => @asset, :style => "original") unless errors
        rescue ActiveRecord::RecordInvalid => e
          @rescued_exception = e
          errors = true
        end
      end
    end

    respond_to do |format|
      if !errors && @asset.errors.empty? && @asset.resource.errors.empty?
        flash[:notice] = if params[:crop_resize_save_as_new].present?
          t('ubiquo.media.image_saved_as_new')
        else
          t('ubiquo.media.image_updated')
        end

        if params[:apply] || params[:save_as_new]
          format.any{ redirect_to(ubiquo.advanced_edit_asset_path(@asset, :target => params[:target]) )}
        elsif params[:target]
          flash.delete :notice
          format.any{ render "advanced_update_target", :layout => false }
        else
          format.html { redirect_to(ubiquo.assets_path) }
          format.xml  { head :ok }
        end
      else
        # Destroy duplicate
        if original_asset
          @asset.destroy
          @asset = original_asset
        end

        if @rescued_exception
          flash[:error] = t('ubiquo.media.asset_original_crop_error') % @rescued_exception.record.errors.full_messages.join(" ")
        else
          flash[:error] = t('ubiquo.media.asset_update_error')
        end
        format.html {
          render :action => "advanced_edit", :layout => false
        }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # POST /assets/1/restore
  def restore
    @asset = Asset.find(params[:id])
    return if uhook_edit_asset(@asset) == false
    if @asset.restore!
      flash[:notice] = t('ubiquo.media.image_updated')
    else
      flash[:error] = t('ubiquo.media.asset_update_error')
    end
    redirect_to ubiquo.advanced_edit_asset_path(@asset, :target => params[:target])
  end


  private

  def load_asset_visibilities
    @asset_visibilities = [
                           OpenStruct.new(:key => 'public', :name => t('ubiquo.media.public')),
                           OpenStruct.new(:key => 'private', :name => t('ubiquo.media.private'))
                          ]
  end

  def load_asset_types
    @asset_types = AssetType.find :all
  end

  def get_visibility(params)
    if (forced_vis = Ubiquo::Settings.context(:ubiquo_media).get(:force_visibility))
      return forced_vis
    end
    if %w{private 1 true}.include?(params[:asset][:is_protected])
      "private"
    else
      "public"
    end
  end

end
