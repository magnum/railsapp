class Api::TestController < Api::BaseController
  def index
    render json: { message: "Hello, world!" }
  end
end
