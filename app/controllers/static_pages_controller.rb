# frozen_string_literal: true

class StaticPagesController < ApplicationController
  layout "application"

  skip_before_action :set_locale, only: :show
  before_action :require_login, except: :show
  before_action :set_static_page, only: %i[edit update destroy]
  before_action :authorize_static_page, only: %i[edit update destroy]

  def index
    authorize StaticPage
    @static_pages = policy_scope(StaticPage).order(:slug)
  end

  def show
    slug = params[:slug].to_s
    requested = params[:locale].presence || session[:locale].presence
    @static_page = StaticPage.find_by(slug: slug)

    if @static_page.nil? || !@static_page.visible_to?(current_user)
      return redirect_to(static_not_found_path(requested)) unless slug == "404"

      @static_page = StaticPage.find_by(slug: "404")
      slug = "404"
    end

    @template = StaticPage.resolve_template(slug, requested)

    unless @template
      return redirect_to(static_not_found_path(requested)) unless slug == "404"

      @template = "404.en"
    end

    I18n.locale = template_locale(@template)
    @template_file = StaticPage.views_path.join("#{@template}.html.erb").to_s
    render :show
  end

  def new
    @static_page = StaticPage.new(state: "created")
    authorize @static_page
  end

  def create
    @static_page = StaticPage.new(static_page_params)
    authorize @static_page

    if @static_page.save
      redirect_to @static_page.public_path, notice: t("static_pages.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @static_page.load_content_from_file!
  end

  def update
    @static_page.assign_attributes(static_page_params)

    if @static_page.save
      redirect_to @static_page.public_path, notice: t("static_pages.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @static_page.destroy
    redirect_to static_pages_path, notice: t("static_pages.destroyed")
  end

  private

  def set_static_page
    @static_page = StaticPage.find_by!(slug: params[:slug])
  end

  def authorize_static_page
    authorize @static_page
  end

  def static_page_params
    params.require(:static_page).permit(:slug, :title, :content, :state)
  end

  def static_not_found_path(requested_locale)
    locale = requested_locale.to_s.presence
    if locale.present? && locale != I18n.default_locale.to_s
      "/#{locale}/404"
    else
      app_not_found_path
    end
  end

  def template_locale(template_name)
    suffix = template_name.to_s.split(".").last
    if StaticPage.available_locale?(suffix)
      suffix.to_sym
    else
      I18n.default_locale
    end
  end

  def skip_modern_browser_check?
    action_name == "show"
  end
end
