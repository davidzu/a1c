# Catch-all for unknown paths (see config/routes.rb). The API contract says
# every error is `{ "error": { code, message, field } }`; without this, Rails
# returns a 404 with an empty body and clients cannot read the failure.
class ErrorsController < ApplicationController
  def not_found
    render_error(code: "not_found", message: "Not found", status: :not_found)
  end
end
