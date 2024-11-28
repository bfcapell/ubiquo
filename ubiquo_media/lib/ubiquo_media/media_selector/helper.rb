module UbiquoMedia
  module MediaSelector
    module Helper
      # Helper to build media selectors.
      #   form => the form object
      #   field => field name, which has been defined as a media_attachment
      #   options => can include the following:
      #     :object_name => to override the form object name
      #     :visibility => visibility for the selector
      #
      def media_selector(form, field, options = {})
        @counter ||= 0
        @counter += 1
        locals = {
          :asset_relations => form.object.send("#{field}_asset_relations"),
          :field => field,
          :field_options => form.object.send("#{field}").options,
          :object => form.object,
          :object_name =>  options[:object_name] || form.object_name.to_s,
          :visibility => Ubiquo::Settings.context(:ubiquo_media).get(:force_visibility) || options[:visibility],
          :counter => "#{form.options[:child_index]}c#{@counter}"
        }
        render :partial => 'ubiquo/asset_relations/media_selector', :locals => locals
      end

      # Returns an <a> element linking to the given asset in a popup
      def view_asset_link(asset)
        link_to(t('ubiquo.media.asset_view'), url_for_media_attachment(asset), :class => 'view', :popup => true)
      end

      # Returns a url where the given asset is accessible
      #
      # params:
      #   asset - The Asset with the media attachment.
      #   style - The Symbol with the name of the style to use (default: nil).
      #   options - The Hash with the options to generate the url (default: {}):
      #             :add_timestamp - Boolean that indicates if a timestamp
      #                              should be added to the end of the url
      #                              as follows:
      #                              /media/url/file.jpg?123456
      def url_for_media_attachment(asset, *args)
        options = args.extract_options!
        style   = args.first
        url = url_for_file_attachment(asset, :resource, style)

        if options[:add_timestamp]
          time = asset.updated_at || asset.created_at || Time.now
          url += "?#{time.to_i.to_s}"
        end

        url
      end

      # Return a selector containing all allowed types for a media_attachment field
      #
      # Example:
      #
      # types = ["image", "doc"].map { |key| AssetType.find_by_key(key) }
      # type_selector("images", types)
      #
      # Returns:
      #
      # "<select id="asset_type_id_images" name="asset_type_id_images">
      #   <option value="1,2">-- All --</option>
      #   <option value="1">Image</option>
      #    <option value="2">Document</option>
      #  </select>"
      def type_selector(counter, types)
        all_opt = [t('ubiquo.media.all'), types.collect(&:id).join(",")]
        type_opts = [all_opt] + types.collect { |t| [t.name, t.id] }
        select_tag "asset_type_id_#{counter}".to_sym, options_for_select(type_opts)
      end

      # Returns the advanced edit path when the asset supports it, nil otherways
      #
      # More options are added to other assets, its told to the view here.
      def advanced_asset_form_for( asset, options = nil)
        ubiquo.advanced_edit_asset_path( asset, options ) if asset.is_resizeable?
      end

      # Parameters to append to a link that brings to advanced_edit form
      def advanced_edit_link_attributes
         {
           :class => "lightwindow action",
           :params => "lightwindow_type=page,lightwindow_width=1038,lightwindow_class=wide",
         }
      end
    end
  end
end

# Helper method for form builders
module ActionView
  module Helpers
    class FormBuilder
      def media_selector(key, options = {})
        @template.media_selector(self, key, options)
      end
    end
  end
end
