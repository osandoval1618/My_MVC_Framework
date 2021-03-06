require 'active_support'
require 'active_support/core_ext'
require 'erb'
require 'active_support/inflector'
require_relative './session'
require_relative './flash'


class ControllerBase
  attr_reader :req, :res, :params

  # Setup the controller
  def initialize(req, res, route_params = {})
    @req = req
    @res = res
    @params = route_params.merge(req.params)
    @@protect_from_forgery ||= false
  end

  # Helper method to alias @already_built_response
  def already_built_response?
    @already_built_response
  end

  # Set the response status code and header
  def redirect_to(url)
    raise "double render error" if already_built_response?
    @res.status = 302
    @res['Location'] = url
    @already_built_response = true

    session.store_session(res)
    flash.store_flash(res)
  end

  # Populate the response with content.
  # Set the response's content type to the given type.
  # Raise an error if the developer tries to double render.
  def render_content(content, content_type)
    raise "double render error" if already_built_response?
    @res.write(content)
    @res['Content-Type'] = content_type
    @already_built_response = true

    flash.store_flash(res)
    session.store_session(@res)
  end

  # use ERB and binding to evaluate templates
  # pass the rendered html to render_content
  def render(template_name)
    controller_file_name = self.class.to_s.underscore #change to get rid of _controller
    current_directory = File.dirname(__FILE__)
    path = File.join(current_directory, '..', 'views', controller_file_name, "#{template_name}.html.erb")

    template = File.read(path)
    html_template = template_with_instance_variables(template)
    render_content(html_template, 'text/html')
  end

  def template_with_instance_variables(template) #make private
    ERB.new(template).result(binding)
  end

  def form_authenticity_token
    @token ||= generate_authenticity_token
    res.set_cookie('authenticity_token', path: '/', value: @token)
    @token
  end

  def check_authenticity_token
    cookie = req.cookies['authenticity_token']
    unless cookie == params['authenticity_token'] && !!cookie
      raise "Invalid authenticity token"
    end
  end

  def protect_from_forgery?
    @@protect_from_forgery
  end

  def self.protect_from_forgery
    @@protect_from_forgery = true
  end

  def generate_authenticity_token
    SecureRandom.urlsafe_base64(16)
  end

  # method exposing a `Session` object
  def session
    @session ||= Session.new(req)
  end

  def flash
    @flash ||= Flash.new(req)
  end

  # use this with the router to call action_name (:index, :show, :create...)
  def invoke_action(name)
    if (protect_from_forgery? && req.request_method != 'GET')
      check_authenticity_token
    else
      form_authenticity_token
    end

    send(name)
    render(name) unless already_built_response?
  end


end
