module ArtPiecesHelper
  # Deep link that opens WhatsApp with a message already drafted, so the buyer
  # only has to hit send. Returns nil when the artist hasn't given a number,
  # which is the signal to hide the contact button entirely.
  def whatsapp_inquiry_url(art_piece, page_url:)
    artist = art_piece.user
    return nil unless artist.whatsapp?

    message = [
      "Hi #{artist.public_name}, I'm interested in \"#{art_piece.title}\"",
      art_piece.priced? ? " (#{art_piece.formatted_price})" : "",
      ".\n#{page_url}"
    ].join

    "https://wa.me/#{artist.whatsapp_phone}?#{{ text: message }.to_query}"
  end
end
