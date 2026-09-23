class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render_error(code: "not_found", message: "Not found", status: :not_found)
  end

  private

  def render_error(code:, message:, field: nil, status:)
    render json: { error: { code: code, message: message, field: field } }, status: status
  end

  def render_validation(record)
    error = record.errors.first
    render_error(
      code: "validation_failed",
      message: record.errors.full_messages.first,
      field: error&.attribute&.to_s,
      status: :unprocessable_content
    )
  end
end
