# A handout's image (Message, kind handout), only for the table. Served from
# here rather than Active Storage's own routes, whose signed URLs work for
# anyone holding them. The type was checked against the file itself
# (Message::IMAGE_TYPES), so it's always a plain raster image.
class Campaigns::Messages::ImagesController < ApplicationController
  include CampaignScoped

  def show
    message = Current.campaign.messages.visible_to(Current.membership).find(params[:message_id])
    raise ActiveRecord::RecordNotFound unless message.image.attached?

    response.headers["X-Content-Type-Options"] = "nosniff"
    expires_in 1.hour, private: true
    send_data message.image.download, type: message.image.blob.content_type, disposition: :inline, filename: message.image.filename.to_s
  end
end
