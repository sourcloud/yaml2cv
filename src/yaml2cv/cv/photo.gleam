//// Validation of profile photos given as data URIs (ADR 0028).
////
//// Only JPEG and PNG are accepted. The file signature must match the
//// declared media type, and the pixel size is read from the image header so
//// that a small file cannot expand into a huge bitmap when Typst decodes it.

import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import yaml2cv/cv.{type Photo, type PhotoFormat, Jpeg, Photo, Png}

/// Why a value is not an acceptable photo. None of the variants carry the
/// value itself, so errors never repeat personal data.
pub type PhotoError {
  /// Not a `data:image/jpeg;base64,` or `data:image/png;base64,` URI.
  NotAPhotoDataUri
  /// The base64 does not decode or the bytes are not an image of the
  /// declared type.
  InvalidImage
  /// The decoded image is larger than `max_bytes`.
  TooLarge(max_bytes: Int)
  /// The image is wider or taller than `max_side` pixels.
  TooManyPixels(max_side: Int)
}

/// The largest accepted photo file in bytes.
pub const max_bytes = 524_288

/// The largest accepted width and height in pixels.
pub const max_side = 4000

const prefixes = [
  #("data:image/jpeg;base64,", Jpeg),
  #("data:image/png;base64,", Png),
]

/// Reads and validates a photo from a base64 data URI.
pub fn from_data_uri(uri: String) -> Result(Photo, PhotoError) {
  use #(format, encoded) <- result.try(split_uri(uri))
  let encoded = strip_whitespace(encoded)
  // Every 4 base64 characters hold 3 bytes; reject before decoding.
  use <- guard(
    string.byte_size(encoded) / 4 * 3 > max_bytes + 2,
    TooLarge(max_bytes:),
  )
  use data <- result.try(
    bit_array.base64_decode(encoded) |> result.replace_error(InvalidImage),
  )
  use <- guard(bit_array.byte_size(data) > max_bytes, TooLarge(max_bytes:))
  use #(width, height) <- result.try(dimensions(format, data))
  use <- guard(width < 1 || height < 1, InvalidImage)
  use <- guard(width > max_side || height > max_side, TooManyPixels(max_side:))
  Ok(Photo(format:, data:))
}

/// The file name the photo is handed to the renderer under.
pub fn file_name(photo: Photo) -> String {
  case photo.format {
    Jpeg -> "photo.jpg"
    Png -> "photo.png"
  }
}

fn guard(
  condition: Bool,
  error: PhotoError,
  next: fn() -> Result(a, PhotoError),
) -> Result(a, PhotoError) {
  case condition {
    True -> Error(error)
    False -> next()
  }
}

fn split_uri(uri: String) -> Result(#(PhotoFormat, String), PhotoError) {
  prefixes
  |> list.find_map(fn(prefix) {
    case string.starts_with(uri, prefix.0) {
      True -> Ok(#(prefix.1, string.drop_start(uri, string.length(prefix.0))))
      False -> Error(Nil)
    }
  })
  |> result.replace_error(NotAPhotoDataUri)
}

fn strip_whitespace(text: String) -> String {
  ["\n", "\r", "\t", " "]
  |> list.fold(text, fn(text, whitespace) {
    string.replace(text, whitespace, "")
  })
}

fn dimensions(
  format: PhotoFormat,
  data: BitArray,
) -> Result(#(Int, Int), PhotoError) {
  case format, data {
    Png,
      <<
        0x89,
        "PNG\r\n",
        0x1A,
        "\n",
        _length:32,
        "IHDR",
        width:32,
        height:32,
        _:bytes,
      >>
    -> Ok(#(width, height))
    Jpeg, <<0xFF, 0xD8, segments:bytes>> -> jpeg_dimensions(segments)
    _, _ -> Error(InvalidImage)
  }
}

/// Walks the JPEG segments up to the first frame header (`SOFn`).
fn jpeg_dimensions(data: BitArray) -> Result(#(Int, Int), PhotoError) {
  case data {
    // Fill bytes before a marker.
    <<0xFF, 0xFF, rest:bytes>> -> jpeg_dimensions(<<0xFF, rest:bits>>)
    // Markers without a length.
    <<0xFF, marker, rest:bytes>>
      if marker == 0x01 || { marker >= 0xD0 && marker <= 0xD7 }
    -> jpeg_dimensions(rest)
    <<0xFF, marker, length:16, rest:bytes>> if length >= 2 ->
      case is_frame_header(marker), rest {
        True, <<_precision, height:16, width:16, _:bytes>> ->
          Ok(#(width, height))
        True, _ -> Error(InvalidImage)
        False, _ -> {
          let skip = length - 2
          case marker, rest {
            // Image data or end of image before any frame header.
            0xDA, _ | 0xD9, _ -> Error(InvalidImage)
            _, <<_:bytes-size(skip), next:bytes>> -> jpeg_dimensions(next)
            _, _ -> Error(InvalidImage)
          }
        }
      }
    _ -> Error(InvalidImage)
  }
}

/// `SOF0`–`SOF15`, except `DHT` (`C4`), `JPG` (`C8`) and `DAC` (`CC`).
fn is_frame_header(marker: Int) -> Bool {
  marker >= 0xC0
  && marker <= 0xCF
  && marker != 0xC4
  && marker != 0xC8
  && marker != 0xCC
}
