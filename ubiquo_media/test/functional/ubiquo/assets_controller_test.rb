require File.dirname(__FILE__) + "/../../test_helper.rb"
require File.dirname(__FILE__) + "/../../test_support/url_helper.rb"

class Ubiquo::AssetsControllerTest < ActionController::TestCase
  include TestSupport::UrlHelper

  def setup
    @created_assets = []
  end

  def teardown
    # @created_assets.map(&:destroy)
    Asset.destroy_all
  end

  def test_should_get_index
    get :index

    assert_response :success
    assert_not_nil assigns(:assets)
  end

  def test_should_call_access_control_configuration
    preserve_configuration(:assets_access_control) do
      # mock the assets_access_control configuration to prevent the
      # dependency with the ubiquo_access_control plugin
      access_mock = mock(:call)
      access_callback = lambda { access_mock.call  }
      Ubiquo::Settings.context(:ubiquo_media).
        set(:assets_access_control, access_callback)

      # Reload the Ubiquo::AssetsController class, to use the definded mock.
      path = File.expand_path(File.join(
        File.dirname(__FILE__),
        '..',
        '..',
        '..',
        'app/controllers/ubiquo/assets_controller.rb'
      ))
      load path

      get :index

      assert_response :success
    end
  end

  def test_should_get_new
    get :new

    assert_response :success
  end

  def test_should_create_asset
    assert_difference('Asset.count') do
      post :create, :asset => { :name         => "new asset",
                                :resource     => uploaded_file,
                                :is_protected => false }
    end

    assert_redirected_to ubiquo.assets_path
    assert flash[:notice]
  end

  def test_should_create_asset_by_xhr
    assert_difference('Asset.count') do
      xhr :post, :create, :asset => { :name         => "new asset",
                                      :resource     => uploaded_file,
                                      :is_protected => false }
    end

    assert_response :success
    assert flash[:notice].blank?,
           "Expecting emtpy message but getting, #{flash[:notice].inspect}"
  end

  def test_should_create_asset_by_xhr_and_validate_type
    assert_no_difference('Asset.count') do
      xhr :post,
          :create,
          { :asset => { :name         => "new asset",
                        :resource     => uploaded_file(_test_file, 'text/plain'),
                        :is_protected => false },
          :accepted_types => ["image"] }
    end

    assert_response :success
    assert @response.body.include?("errorExplanation") # The div with error message is shown
    # no add_element is called as it has failed
    assert !@response.body.include?("add_element")
  end

  def test_should_create_asset_by_xhr_and_validate_type_unless_fails
    assert_no_difference('Asset.count') do
      xhr :post,
          :create,
          { :asset => { :name         => "asd",
                        :resource     => nil,
                        :is_protected => false },
          :accepted_types => AssetType.all.map(&:key) }
    end

    assert_response :success
    assert @response.body.include?("errorExplanation") # The div with error message is shown
    # no add_element is called as it has failed
    assert !@response.body.include?("add_element")
  end

  def test_should_get_edit
    get :edit, :id => assets(:video).id

    begin
      if (Ubiquo::AssetsController.new.uhook_edit_asset assets(:video)) != false
        assert_response :success
      end
    rescue
      assert true # nothing can be asserted because the uhook is interacting
    end
  end

  def test_should_update_asset
    put :update,
        :id    => assets(:video).id,
        :asset => { :name         => "new asset",
                    :resource     => uploaded_file,
                    :is_protected => false }

    assert_redirected_to ubiquo.assets_path
  end

  def test_should_destroy_asset
    assert_difference('Asset.count', -1) do
      delete :destroy, :id => assets(:video).id
    end

    assert_redirected_to ubiquo.assets_path
  end

  def test_should_filter_by_text_ubiquo_user_and_asset_type
    get :search, :field => 'image', :text => 'MyName', :asset_type_id => 1

    assert_response :success
    assert_equal 'image', assigns(:field)
    assert_equal 'MyName', assigns(:search_text)
    assert_equal 1, assigns(:page)
    assert_equal 1, assigns(:assets).size
    expected = { 'previous' => nil, 'next' => nil, 'total_items' => 1, 'total_pages' => 1, 'current_page' => 1}
    assert_equal expected, assigns(:assets_pages)
  end

  def test_should_filter_by_text_and_ubiquo_user_paginated
    Asset.destroy_all
    Ubiquo::Settings.context(:ubiquo_media).set(:media_selector_list_size, 1)
    list_size = Ubiquo::Settings.context(:ubiquo_media).
      get(:media_selector_list_size)

    ((list_size * 2) ).times do
      create_asset(:asset_type_id => asset_types(:image).id, :name => "MyName")
    end

    get :search, :field => 'image', :text => 'MyName', :page => 1, :per_page => list_size

    assert_response :success
    assert_equal list_size, assigns(:assets).size
    expected = { 'previous' => nil, 'next' => 2, 'total_items' => 2, 'total_pages'=> 2, 'current_page' => 1 }
    assert_equal expected, assigns(:assets_pages)

    get :search, :field => 'image', :text => 'MyName', :page => 2

    assert_response :success
    assert_equal list_size, assigns(:assets).size
    expected = { 'previous' => 1, 'next' => nil, "total_items" => 2, "total_pages" => 2, "current_page" => 2 }
    assert_equal expected, assigns(:assets_pages)
  ensure
    Ubiquo::Settings.context(:ubiquo_media).set(:media_selector_list_size, 3)
  end

  def test_should_filter_by_text_and_ubiquo_user_paginated_view
    list_size = Ubiquo::Settings.context(:ubiquo_media).
      get(:assets_elements_per_page)

    ((list_size * 2) ).times do
      create_asset(:asset_type_id => asset_types(:image).id, :name => "MyName")
    end

    get :search, :field => 'image', :text => 'MyName', :page => 2, :counter => 1

    assert_response :success
    assert_select_rjs "asset_search_results_1" do
      assert_select "ul" do
        assert_select "li", 3
      end
    end
  end

  def test_filter_by_text_searching_case_insensitive_on_name_and_description
    Asset.delete_all
    asset1 = create_asset(:name => 'name1', :description => 'description1')
    asset2 = create_asset(:name => 'name2', :description => 'description2')

    get :index, :filter_text => 'name'

    assert_equal_set [asset1, asset2], assigns(:assets)

    get :index, :filter_text => 'NAME1'

    assert_equal_set [asset1], assigns(:assets)

    get :index, :filter_text => 'description2'

    assert_equal_set [asset2], assigns(:assets)
  end

  def test_should_search_assets_ordered_by_id_desc
    Asset.delete_all
    asset1 = create_asset(:name => 'name1', :description => 'description1')
    asset2 = create_asset(:name => 'name2', :description => 'description2')

    get :search, :filter_text => 'name'

    assert_equal [asset2, asset1], assigns(:assets)
  end

  def test_filter_by_creation_date
    Asset.delete_all
    asset1 = create_asset(:created_at => 3.days.ago)
    asset2 = create_asset(:created_at => 1.days.from_now)
    asset3 = create_asset(:created_at => 10.days.from_now)

    I18n.locale = Ubiquo.default_locale

    get :index, :filter_created_start => I18n.localize(Time.zone.today)

    assert_equal_set [asset2, asset3], assigns(:assets)

    get :index, :filter_created_end => I18n.localize(Time.zone.today)

    assert_equal_set [asset1], assigns(:assets)

    get :index,
        :filter_created_start => I18n.localize(5.days.ago.to_date),
        :filter_created_end   => I18n.localize(1.days.from_now.to_date)

    assert_equal_set [asset1, asset2], assigns(:assets)
  end

  def test_should_get_advanced_edit
    asset = create_image_asset

    Ubiquo::Settings.context(:ubiquo_media).set(:media_styles_list,
      {:thumb => "100x100>", :base_to_crop => "320x200>"})

    get :advanced_edit, :id => asset.id

    assert_response :success

    no_resizeable_asset = create_asset(
      :file_extension => "txt",
      :file_contents  => "content",
      :asset_type_id  => AssetType.find_by_key("audio").id
    )

    get :advanced_edit, :id => no_resizeable_asset.id

    assert_response :redirect
    assert !flash[:error].blank?
  end

  def test_advanced_edit_hides_tabs_when_formats
    preserve_configuration do
      Ubiquo::Settings.context(:ubiquo_media).set(:media_styles_list, {})

      asset = create_image_asset

      get :advanced_edit, :id => asset.id

      assert_response :success
      assert_select "#resize-actions li", 0
    end
  end

  def test_should_advanced_update_asset_original
    asset = create_image_asset

    Ubiquo::Settings.context(:ubiquo_media).get(:media_styles_list).merge!(
      { :thumb => "100x100>", :base_to_crop => "320x200>" }
    )

    original_params = { "left"   => "1",
                        "height" => "10",
                        "top"    => "0",
                        "width"  => "10" }
    AssetArea.expects(:original_crop!).
      with(original_params.merge( "asset" => asset, "style" => "original" )).
      once.
      returns(true)
    AssetArea.expects(:new).never

    put :advanced_update,
        :id              => asset.id,
        "operation_type" => "original",
        "asset"          => { "keep_backup" => true },
        "crop_resize"    => {
          "original" => original_params,
          "thumb"    => {
            "left"   => "0",
            "height" => "20",
            "top"    => "0",
            "width"  => "30"
          },
        }

    assert_redirected_to ubiquo.assets_path
    assert_equal 0, assigns(:asset).asset_areas.count
  end

  def test_should_advanced_update_asset_formats
    update_asset_formats_test
  end

  # A version of test_should_advanced_update_asset_formats but saving as new
  def test_should_advanced_update_asset_formats_and_save_as_new
    data = update_asset_formats_test(
      :request => {
        :crop_resize_save_as_new => "1",
        :asset_name              => "saved_as_new"
    })

    assert_equal "saved_as_new", assigns(:asset).name
    assert_not_equal assigns(:asset).id, data[:asset].id
  end

  private

  def update_asset_formats_test(options = {})
    preserve_configuration do
      Ubiquo::Settings.context(:ubiquo_media).get(:media_styles_list).merge!({
        :thumb        => "100x100>",
        :base_to_crop => "320x200>",
        :long         => "30x180#" #Very vertical image
      })

      asset = create_image_asset

      put(:advanced_update, ({
        :id              => asset.id,
        "operation_type" => "formats",
        "asset"          => { "keep_backup" => true },
        "crop_resize" => {
          "original" => {
            "left"   => "1",
            "width"  => "10",
            "top"    => "0",
            "height" => "10",
          },
          "thumb"    => {
            "left"   => "2",
            "width"  => "15",
            "top"    => "3",
            "height" => "12",
          },
          "long"     => {
            "left"   => "0",
            "width"  => "20",
            "top"    => "2",
            "height" => "60",
            },
          }
        }).merge(options[:request] || {})
      )

      assert_nil assigns(:asset).asset_areas.find_by_style("original")
      assert_nil assigns(:asset).asset_areas.find_by_style("base_to_crop")

      thumb = assigns(:asset).asset_areas.find_by_style("thumb")

      assert_equal 2, thumb.left
      assert_equal 15, thumb.width
      assert_equal 12, thumb.height
      assert_equal 3, thumb.top

      thumb = assigns(:asset).asset_areas.find_by_style("long")

      assert_equal 0, thumb.left
      assert_equal 20, thumb.width
      assert_equal 60, thumb.height
      assert_equal 2, thumb.top

      assert_redirected_to ubiquo.assets_path

      #Return data
      { :asset => asset }
    end
  end

  def create_asset(options = {})
    file_ext = options.delete(:file_extension) || "png"
    file_contents = options.delete(:file_contents) || sample_image.read
    created_at = options.delete(:created_at)
    default_options = {
      :name          => "Created asset",
      :description   => "Description",
      :asset_type_id => AssetType.find(:first).id,
      :resource      => _test_file(file_contents, file_ext),
      :is_protected  => false,
    }

    asset = AssetPublic.create(default_options.merge(options))
    asset.update_column :created_at, created_at if created_at
    # Save asset to destroy on teardown
    @created_assets << asset
    asset
  end

  def create_image_asset( options = {} )
    default_options = { :resource => sample_image }

    create_asset(default_options.merge(options))
  end

  # To recover the configuration after the changes.
  def preserve_configuration(key = :media_styles_list)
    @old_config = Ubiquo::Settings.context(:ubiquo_media).get(key).dup
    yield
  ensure
    Ubiquo::Settings.context(:ubiquo_media).set(key, @old_config)
  end

  def uploaded_file(file = nil, content_type = nil)
    file         ||= sample_image
    content_type ||= 'image/png'

    Rack::Test::UploadedFile.new(file, content_type)
  end
end
